# the following objects are required by Makara

unless defined?(Concurrent)
  module Concurrent
    def self.monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_second)
    end
  end
end

unless defined?(Time::RFC2822_DAY_NAME)
  Time::RFC2822_DAY_NAME = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].freeze
end

unless defined?(Time::RFC2822_MONTH_NAME)
  Time::RFC2822_MONTH_NAME = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'].freeze
end
