require 'delegate'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/string/inflections'

# The entry point of Makara. It contains a master and slave pool which are chosen based on the invocation
# being proxied.
# While debugging this class use prepend debug calls with Kernel. (Kernel.byebug for example)
# to avoid getting into method_missing stuff.

module Makara
  class Proxy < ::SimpleDelegator
    METHOD_MISSING_SKIP = [ :byebug, :puts ].freeze

    HIJACK_METHODS = [:execute, :exec_query, :exec_no_cache, :exec_cache, :transaction].freeze

    class << self
      def hijack_methods
        HIJACK_METHODS.each do |method_name|
          define_method(method_name) do |*args, &block|
            appropriate_connection(method_name, args) do |con|
              con.send(method_name, *args, &block)
            end
          end

          ruby2_keywords method_name if Module.private_method_defined?(:ruby2_keywords)
        end
      end

      def send_to_all(*method_names)
        method_names.each do |method_name|
          define_method(method_name) do |*args|
            send_to_all(method_name, *args)
          end

          ruby2_keywords method_name if Module.private_method_defined?(:ruby2_keywords)
        end
      end
    end

    attr_reader :error_handler
    attr_reader :sticky
    attr_reader :config_parser

    def initialize(config)
      @config         = config.symbolize_keys
      @config_parser  = Makara::ConfigParser.new(@config)
      @id             = @config_parser.id
      @ttl            = @config_parser.makara_config[:master_ttl]
      @sticky         = @config_parser.makara_config[:sticky]
      @hijacked       = false
      @error_handler  ||= ::Makara::ErrorHandler.new
      @skip_sticking  = false
      instantiate_connections
      super(config)
    end

    def without_sticking
      @skip_sticking = true
      yield
    ensure
      @skip_sticking = false
    end

    def hijacked?
      @hijacked
    end

    # If persist is true, we stick the proxy to master for subsequent requests
    # up to master_ttl duration. Otherwise we just stick it for the current request
    def stick_to_master!(persist = true)
      stickiness_duration = persist ? @ttl : 0
      Makara::Context.stick(@id, stickiness_duration)
    end

    def strategy_for(role)
      strategy_class_for(strategy_name_for(role)).new(self)
    end

    def strategy_name_for(role)
      @config_parser.makara_config["#{role}_strategy".to_sym]
    end

    def shard_aware_for(role)
      @config_parser.makara_config["#{role}_shard_aware".to_sym]
    end

    def default_shard_for(role)
      @config_parser.makara_config["#{role}_default_shard".to_sym]
    end

    def strategy_class_for(strategy_name)
      case strategy_name
      when 'round_robin', 'roundrobin', nil, ''
        ::Makara::Strategies::RoundRobin
      when 'failover'
        ::Makara::Strategies::PriorityFailover
      else
        strategy_name.constantize
      end
    end

    # called for any method not defined here
    def method_missing(m, *args, &block)
      if METHOD_MISSING_SKIP.include?(m)
        return super
      end

      any_connection do |con|
        if con.respond_to?(m, true)
          con.send(m, *args, &block)
        else
          super
        end
      end
    end

    ruby2_keywords :method_missing if Module.private_method_defined?(:ruby2_keywords)

    def respond_to_missing?(m, _include_private = false)
      any_connection do |con|
        con._makara_connection.respond_to?(m, true)
      end
    end

    def graceful_connection_for(config)
      fake_wrapper = Makara::ConnectionWrapper.new(self, nil, config)

      @error_handler.handle(fake_wrapper) do
        connection_for(config)
      end
    rescue Makara::Errors::BlacklistConnection => e
      fake_wrapper.initial_error = e.original_error
      fake_wrapper
    end

    # disconnect all underlying connections
    def disconnect!
      send_to_all(:disconnect!)
    rescue ::Makara::Errors::AllConnectionsBlacklisted, ::Makara::Errors::NoConnectionsAvailable
      # all connections are already down, nothing to do here
    end

    protected

    def send_to_all(method_name, *args)
      # slave pool must run first to allow for slave-->master failover without running operations on master twice.
      handling_an_all_execution(method_name) do
        @slave_pool.send_to_all(method_name, *args)
        @master_pool.send_to_all(method_name, *args)
      end
    end

    ruby2_keywords :send_to_all if Module.private_method_defined?(:ruby2_keywords)

    def any_connection
      if @master_pool.disabled
        @slave_pool.provide do |con|
          yield con
        end
      else
        @master_pool.provide do |con|
          yield con
        end
      end
    rescue ::Makara::Errors::AllConnectionsBlacklisted, ::Makara::Errors::NoConnectionsAvailable
      begin
        @master_pool.disabled = true
        @slave_pool.provide do |con|
          yield con
        end
      ensure
        @master_pool.disabled = false
      end
    end

    # based on the method_name and args, provide the appropriate connection
    # mark this proxy as hijacked so the underlying connection does not attempt to check
    # with back with this proxy.
    def appropriate_connection(method_name, args)
      appropriate_pool(method_name, args) do |pool|
        pool.provide do |connection|
          hijacked do
            yield connection
          end
        end
      end
    end

    # master or slave
    def appropriate_pool(method_name, args)
      # for testing purposes
      pool = _appropriate_pool(method_name, args)
      yield pool
    rescue ::Makara::Errors::AllConnectionsBlacklisted, ::Makara::Errors::NoConnectionsAvailable => e
      if pool == @master_pool
        @master_pool.connections.each(&:_makara_whitelist!)
        @slave_pool.connections.each(&:_makara_whitelist!)
        Kernel.raise e
      else
        @master_pool.blacklist_errors << e
        retry
      end
    end

    def _appropriate_pool(method_name, args)
      # the args provided absolutely need master
      if needs_master?(method_name, args)
        stick_to_master(method_name, args)
        @master_pool

      elsif stuck_to_master?

        # we're on master because we already stuck this proxy in this
        # request or because we got stuck in previous requests and the
        # stickiness is still valid
        @master_pool

      # all slaves are down (or empty)
      elsif @slave_pool.completely_blacklisted?  # rubocop:disable Lint/DuplicateBranch
        stick_to_master(method_name, args)
        @master_pool

      elsif in_transaction?  # rubocop:disable Lint/DuplicateBranch
        @master_pool

      # yay! use a slave
      else
        @slave_pool
      end
    end

    # do these args require a master connection
    def needs_master?(_method_name, _args)
      true
    end

    def in_transaction?
      if respond_to?(:open_transactions)
        self.open_transactions > 0
      else
        false
      end
    end

    def hijacked
      @hijacked = true
      yield
    ensure
      @hijacked = false
    end

    def stuck_to_master?
      sticky? && Makara::Context.stuck?(@id)
    end

    def stick_to_master(method_name, args)
      # check to see if we're configured, bypassed, or some custom implementation has input
      return unless should_stick?(method_name, args)

      # do the sticking
      stick_to_master!
    end

    # For the generic proxy implementation, we stick if we are sticky,
    # method and args don't matter
    def should_stick?(_method_name, _args)
      sticky?
    end

    # If we are configured to be sticky and we aren't bypassing stickiness,
    def sticky?
      @sticky && !@skip_sticking
    end

    # use the config parser to generate a master and slave pool
    def instantiate_connections
      @master_pool = Makara::Pool.new('master', self)
      @config_parser.master_configs.each do |master_config|
        @master_pool.add master_config do
          graceful_connection_for(master_config)
        end
      end

      @slave_pool = Makara::Pool.new('slave', self)
      @config_parser.slave_configs.each do |slave_config|
        @slave_pool.add slave_config do
          graceful_connection_for(slave_config)
        end
      end
    end

    def handling_an_all_execution(_method_name)
      yield
    rescue ::Makara::Errors::NoConnectionsAvailable => e
      if e.role == 'master'
        # this means slave connections are good.
        return
      end

      @slave_pool.disabled = true
      yield
    ensure
      @slave_pool.disabled = false
    end

    def connection_for(_config)
      Kernel.raise NotImplementedError
    end
  end
end
