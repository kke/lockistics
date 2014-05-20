module Lockistics

  class LockTimeout < StandardError; end

  class Lock

    attr_accessor :key, :options, :lock_retries

    LUA_ACQUIRE = "return redis.call('setnx', KEYS[1], 1) == 1 and redis.call('expire', KEYS[1], KEYS[2]) and 1 or 0"

    def initialize(key, options={})
      @key     = key
      @options = Lockistics.configuration.lock_defaults.merge(options)
      @options[:expire] = 999_999_999 unless @options[:expire].to_i > 0 # :expire => false
      @exceeded_before_release = false
      @lock_retries = 0
    end

    def acquire_lock
      return true if options[:pass_through]
      Lockistics.known_keys(key)
      if got_lock?
        true
      elsif options[:wait]
        wait_for_lock
      else
        false
      end
    end

    def wait_for_lock
      until got_lock?
        @lock_retries += 1
        if lock_retries <= options[:retries]
          sleep options[:sleep]
        elsif options[:raise]
          raise LockTimeout, "while waiting for #{key}"
        else
          return false
        end
      end
      true
    end

    def exceeded_before_release?
      @exceeded_before_release
    end

    def release_lock
      return true if options[:pass_through]
      @exceeded_before_release = redis.del(namespaced_key) == 0
    end

    def namespaced_key
      @namespaced_key ||= "#{Lockistics.configuration.namespace}.lock.#{key}"
    end

    private

    def redis
      Lockistics.redis
    end

    def got_lock?
      redis.eval(LUA_ACQUIRE, [namespaced_key, options[:expire]]) == 1
    end

  end
end
