module Makara
  module VERSION
    MAJOR = 0
    MINOR = 5
    PATCH = 2
    PRE = 3

    def self.to_s
      [MAJOR, MINOR, PATCH, PRE].compact.join('.')
    end
  end unless defined?(::Makara::VERSION)
  ::Makara::VERSION
end
