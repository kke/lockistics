require 'time'
module Lockistics
  class Statistics

    attr_accessor :key

    def initialize(key)
      @key = key
    end

    def last_run
      unix_time = redis.get(namespaced("#{key}.last_run"))
      if unix_time
        Time.at(unix_time.to_i)
      end
    end

    def all(since=nil)
      {
        :daily => daily(since),
        :hourly => hourly(since),
        :total => total,
        :last_run => last_run
      }
    end

    def daily(since=nil)
      daily_hashes(since).collect{|stamped| redis.hgetall(stamped.first).merge(:time => stamped.last )}
    end

    def hourly(since=nil)
      hourly_hashes(since).collect{|stamped| redis.hgetall(stamped.first).merge(:time => stamped.last)}
    end

    def total
      redis.hgetall total_hash
    end

    private

    def date_to_hourly_stamp(date=nil)
      if date.nil?
        0
      elsif date.respond_to?(strftime)
        date.strftime("%Y%m%d%H")
      elsif date.match(/^\d+$/)
        Time.at(date).strftime("%Y%m%d%H")
      end
    end

    def date_to_daily_stamp(date=nil)
      if date.nil?
        0
      elsif date.respond_to?(strftime)
        date.strftime("%Y%m%d")
      elsif date.match(/^\d+$/)
        Time.at(date).strftime("%Y%m%d")
      end
    end

    def redis
      Lockistics.redis
    end

    def daily_hashes(since=nil)
      stamped_ts = date_to_daily_stamp(since)
      redis.smembers(namespaced("#{key}.dailies")).collect do |ts|
        next if ts.to_i < stamped_ts
        [namespaced("#{key}.daily.#{ts}"), Time.parse(ts)]
      end
    end

    def hourly_hashes(since=nil)
      stamped_ts = date_to_hourly_stamp(since)
      redis.smembers(namespaced("#{key}.hourlies")).collect do |ts|
        next if ts.to_i < stamped_ts
        [namespaced("#{key}.hourly.#{ts}"), Time.parse(ts)]
      end
    end

    def total_hash
      namespaced "#{key}.total"
    end

    def namespaced(extra_key=nil)
      "#{Lockistics.configuration.namespace}#{extra_key.nil? ? "" : ".#{extra_key}"}"
    end
  end
end
