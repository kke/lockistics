require 'os'

module Lockistics
  class DummyMeter
    def method_missing(*args, &block)
      # do nothing
    end
  end

  class Meter

    attr_accessor :key, :options

    LUA_SETMAX = <<-EOB.gsub("\n", " ").gsub(/\s+/, " ")
      if redis.call("hexists", KEYS[1], KEYS[2]) == 0 or
         tonumber(redis.call("hget", KEYS[1], KEYS[2])) < tonumber(ARGV[1])
      then
        return redis.call("hset", KEYS[1], KEYS[2], ARGV[1])
      else
        return 0
      end
    EOB

    LUA_SETMIN = <<-EOB.gsub("\n", " ").gsub(/\s+/, " ")
      if redis.call("hexists", KEYS[1], KEYS[2]) == 0 or
         tonumber(redis.call("hget", KEYS[1], KEYS[2])) > tonumber(ARGV[1])
      then
        return redis.call("hset", KEYS[1], KEYS[2], ARGV[1])
      else
        return 0
      end
    EOB

    def initialize(key, options={})
      @key     = key
      @options = {:pass_through => Lockistics.configuration.pass_through}.merge(options)
      @lock_timeouts = 0
    end

    def with_lock(&block)
      raise ArgumentError, "with_lock called without block" unless block_given?
      raise ArgumentError, "lock not defined" if lock.nil?
      lock.acquire_lock
      yield self
    ensure
      lock.release_lock
    end

    def perform(&block)
      raise ArgumentError, "perform called without block" unless block_given?
      if options[:pass_through]
        yield DummyMeter.new
      else
        before_perform
        lock ? with_lock(&block) : yield(self)
      end
    rescue Lockistics::LockTimeout
      @lock_timeouts = 1
      raise
    ensure
      after_perform unless options[:pass_through]
    end

    # You can add custom metrics during runtime
    #
    # @example
    #   Lockistics.meter do |meter|
    #     foo = FooGenerator.new
    #     foo.perform
    #     meter.incrby 'foos-generated', foo.count
    #   end
    def incrby(key, value)
      return nil if value == 0
      [:hourly, :daily, :total].each do |period|
        redis.hincrby namespaced_hash(period), key, value
      end
    end

    # You can add custom metrics during runtime with
    # this.
    #
    # This is a shortcut to incrby(key, 1)
    #
    # @example
    #   Lockistics.meter do |meter|
    #     foo = FooGenerator.new
    #     foo.perform
    #     meter.incr 'failed-foo-generations' unless foo.success?
    #   end
    def incr(key)
      incrby(key, 1)
    end

    def set_minmax(key, value)
      [:hourly, :daily, :total].each do |period|
        redis_hsetmax(namespaced_hash(period), "max.#{key}", value)
        redis_hsetmin(namespaced_hash(period), "min.#{key}", value)
      end
    end

    private

    def redis
      Lockistics.configuration.redis
    end

    def redis_hsetmax(hash, key, value)
      redis.eval(LUA_SETMAX, [hash, key], [value]) == 1
    end

    def redis_hsetmin(hash, key, value)
      redis.eval(LUA_SETMIN, [hash, key], [value]) == 1
    end

    def lock
      options[:lock]
    end

    def before_perform
      Lockistics.known_keys(key) unless options[:no_metrics]
      @start_time = Time.now.to_f
      # Sometimes you get 'Cannot allocate memory - ps -o rss= -p 15964'
      begin
        @start_rss  = OS.rss_bytes
      rescue
        @start_rss  = nil
      end
      redis.pipelined do
        redis.sadd "#{Lockistics.configuration.namespace}.#{key}.hourlies", hourly_timestamp
        redis.sadd "#{Lockistics.configuration.namespace}.#{key}.dailies",  daily_timestamp
        redis.set  "#{Lockistics.configuration.namespace}.#{key}.last_run", Time.now.to_i
      end
    end

    def after_perform
      unless @lock_timeouts > 0
        @duration     = ((Time.now.to_f - @start_time) * 1000).round
        @rss_increase = ((OS.rss_bytes  - @start_rss)  / 1024).round unless @start_rss.nil?
      end
      add_meter_statistics unless options[:no_metrics]
      add_lock_statistics  unless lock.nil?
    end

    def add_meter_statistics
      incrby 'invocations', 1
      set_minmax 'rss',  @rss_increase unless @rss_increase.nil?
      set_minmax 'time', @duration     unless @duration.nil?
    end

    def add_lock_statistics
      redis.pipelined do
        incrby 'lock-invocations', 1
        incrby 'lock-retries', lock.lock_retries
        incrby 'lock-timeouts', @lock_timeouts
        if lock.exceeded_before_release?
          incrby 'lock-exceeded-before-release', 1
        end
      end
    end

    def hourly_timestamp
      @hourly_timestamp ||= Time.now.strftime("%Y%m%d%H")
    end

    def daily_timestamp
      @daily_timestamp ||= Time.now.strftime("%Y%m%d")
    end

    def namespaced_hash(period)
      case period
      when :hourly
        "#{Lockistics.configuration.namespace}.#{key}.hourly.#{hourly_timestamp}"
      when :daily
        "#{Lockistics.configuration.namespace}.#{key}.daily.#{daily_timestamp}"
      when :total
        "#{Lockistics.configuration.namespace}.#{key}.total"
      end
    end
  end
end
