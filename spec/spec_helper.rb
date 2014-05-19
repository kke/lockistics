require 'rspec'
require 'redis'
require 'fakeredis'
require File.expand_path('../../lib/lockistics.rb', __FILE__)

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.order = 'random'
end

class Redis
  def eval(script, keys=[], args=[])
    case script
    when Lockistics::Lock::LUA_ACQUIRE
      fake_acquire(keys, args)
    when Lockistics::Meter::LUA_SETMAX
      fake_hsetmax(keys, args)
    when Lockistics::Meter::LUA_SETMIN
      fake_hsetmin(keys, args)
    else
      super
    end
  end

  def fake_acquire(keys, args=[])
    return false if existing = get(keys.first)
    if setnx(keys.first, 1)
      expire keys.first, keys.last
      1
    else
      0
    end
  end

  def fake_hsetmax(keys=[], args=[])
    existing = hget(keys[0], keys[1])
    if existing.nil? || args.first > existing.to_i
      hset(keys[0], keys[1], args.first)
      1
    else
      0
    end
  end

  def fake_hsetmin(keys=[], args=[])
    existing = hget(keys[0], keys[1])
    if existing.nil? || args.first < existing.to_i
      hset(keys[0], keys[1], args.first)
      1
    else
      0
    end
  end
end
