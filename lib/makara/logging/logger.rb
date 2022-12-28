module Makara
  module Logging
    class Logger
      class << self
        def log(msg, format = :error)
          logger.send(format, "[Makara] #{msg}") if logger
        end

        def logger
          # probably slightly inefficient but thread-safe
          Logger.new(STDERR)
        end
      end
    end
  end
end
