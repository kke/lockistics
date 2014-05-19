require 'redis'

module Lockistics
  class Configuration

    attr_accessor :redis
    attr_accessor :namespace
    attr_accessor :logger
    attr_accessor :expire
    attr_accessor :sleep
    attr_accessor :retries
    attr_accessor :raise

    def initialize
      @redis     = Redis.new
      @namespace = 'lockistics'
      @expire    = 10
      @sleep     = 0.5
      @retries   = 10
    end

    def lock_defaults
      {
        :redis => redis,
        :namespace => namespace,
        :expire => expire,
        :sleep => sleep,
        :retries => retries,
        :wait => true,
        :raise => true
      }
    end
  end
end
