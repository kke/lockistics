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
    attr_accessor :pass_through
    attr_accessor :meter_rss

    def initialize
      @redis        = Redis.new
      @namespace    = 'lockistics'
      @expire       = 10
      @sleep        = 0.5
      @retries      = 10
      @pass_through = false
      @meter_rss    = false
    end

    def lock_defaults
      {
        :redis => redis,
        :namespace => namespace,
        :expire => expire,
        :sleep => sleep,
        :retries => retries,
        :wait => true,
        :meter_rss => false,
        :raise => true
      }
    end
  end
end
