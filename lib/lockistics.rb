require "lockistics/version"
require "lockistics/configuration"
require "lockistics/lock"
require "lockistics/meter"
require "lockistics/statistics"

# Lockistics is basically a distributed mutex on Redis.
#
# In addition to locking it also collects statistics data
# of the locking events.
#
# You can use each part separately if you just want to
# collect statistics or to do simple locking.
#
# Total, daily and hourly metrics you get for each key are:
#  - Number of locks
#  - Number of times having to wait for lock
#  - Number of failed locking attempts
#  - Minimum and maximum duration
#  - Minimum and maximum memory growth (using OS gem)
#  - Arbitary metrics you add during execution
module Lockistics

  # Configure the gem
  #
  # @example
  #   Lockistics.configure do |config|
  #     config.redis                = Redis.new
  #     config.namespace            = "production.locks"
  #     config.expire               = 300  # seconds
  #     config.sleep                = 0.5  # seconds to sleep between retries
  #     config.retries              = 10   # retry times
  #     config.raise                = true # raise Lockistics::TimeoutException when lock fails
  #   end
  def self.configure(&block)
    yield configuration
  end

  # Returns an instance of Lockistics::Configuration
  def self.configuration
    @configuration ||= Configuration.new
  end

  # Accessor to the redis configured via Lockistics::Configuration
  def self.redis
    configuration.redis
  end

  # Get a hold of a lock or wait for it to be released
  #
  # Given a block, will release the lock after block exection
  #
  # @example
  #   Lockistics.lock("generate-stuff-raketask") do
  #     doing_some_heavy_stuff
  #   end
  #   or
  #   return nil unless Lockistics.lock("generate-stuff", :wait => false)
  #   or
  #   begin
  #     Lockistics.lock("stuff") do
  #       ...
  #     end
  #   rescue Lockistics::Timeout
  #     ...
  #   end
  def self.lock(key, options={}, &block)
    if block_given?
      Meter.new(key, options.merge(:no_metrics => true)).perform(&block)
    else
      Lock.new(key, options).acquire_lock
    end
  end

  # Don't perform locking, just collect metrics.
  #
  # @example
  #   Lockistics.meter("generate-stuff") do |meter|
  #     do_stuff
  #     meter.incrby :stuffs_generated, 50
  #   end
  def self.meter(key, options={}, &block)
    Meter.new(key, options.merge(:lock => nil)).perform(&block)
  end

  # Perform locking and statistics collection
  #
  # @example
  #   Lockistics.meterlock("generate-stuff") do |meter|
  #     results = do_stuff
  #     if results.empty?
  #       meter.incr "empty_results"
  #     else
  #       meter.incrby "stuffs_done", results.size
  #     end
  #   end
  def self.meterlock(key, options={}, &block)
    Meter.new(key, options.merge(:lock => Lock.new(key, options))).perform(&block)
  end

  # Manually release a lock
  #
  # @example
  #   Lockistics.release("generate-stuff")
  #   or
  #   lock = Lockistics.lock("generate-stuff", :wait => false)
  #   if lock.acquire_lock
  #     do_some_stuff
  #     lock.release_lock
  #   end
  def self.release(key, options={})
    Lock.new(key).release_lock
  end

  # Returns an instance of Lockistics::Statistics for the key.
  #
  # @example
  #   stats = Lockistics.statistics('generate-stuff')
  #   stats.last_run
  #     => Mon May 19 16:38:52 +0300 2014
  #   stats.total
  #     => {"invocations" => 50, ...}
  def self.statistics(key)
    Statistics.new(key)
  end

end
