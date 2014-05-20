require File.expand_path('../spec_helper.rb', __FILE__)

describe "Lockistics.meter" do
  it "should collect daily metrics" do
    Lockistics.meter("mtest1") do
      sleep 1
    end
    last_daily_ts = Lockistics.redis.smembers("lockistics.mtest1.dailies").last
    last_daily_ts.should_not be_nil
    last_daily = Lockistics.redis.hgetall("lockistics.mtest1.daily.#{last_daily_ts}")
    last_daily.should be_a Hash
    last_daily["max.time"].to_i.should be > 1000
    last_max_time = last_daily["max.time"].to_i
    last_daily["invocations"].to_i.should eq 1
    Lockistics.meter("mtest1") do
      sleep 3
    end
    last_daily_ts = Lockistics.redis.smembers("lockistics.mtest1.dailies").last
    last_daily_ts.should_not be_nil
    last_daily = Lockistics.redis.hgetall("lockistics.mtest1.daily.#{last_daily_ts}")
    last_daily.should be_a Hash
    last_daily["max.time"].to_i.should be > 2000
    last_daily["min.time"].to_i.should eq last_max_time
    last_daily["invocations"].to_i.should eq 2
    Lockistics.redis.del("lockistics.mtest1.daily.#{last_daily_ts}")
  end

  it "should collect hourly metrics" do
    Lockistics.meter("mtest2") do
      sleep 1
    end
    last_hourly_ts = Lockistics.redis.smembers("lockistics.mtest2.hourlies").last
    last_hourly_ts.should_not be_nil
    last_hourly = Lockistics.redis.hgetall("lockistics.mtest2.hourly.#{last_hourly_ts}")
    last_hourly.should be_a Hash
    last_hourly["max.time"].to_i.should be > 1000
    last_max_time = last_hourly["max.time"].to_i
    last_hourly["invocations"].to_i.should eq 1
    Lockistics.meter("mtest2") do
      sleep 3
    end
    last_hourly_ts = Lockistics.redis.smembers("lockistics.mtest2.hourlies").last
    last_hourly_ts.should_not be_nil
    last_hourly = Lockistics.redis.hgetall("lockistics.mtest2.hourly.#{last_hourly_ts}")
    last_hourly.should be_a Hash
    last_hourly["max.time"].to_i.should be > 2000
    last_hourly["min.time"].to_i.should eq last_max_time
    last_hourly["invocations"].to_i.should eq 2
    Lockistics.redis.del("lockistics.mtest2.hourly.#{last_hourly_ts}")
  end

  it "should collect total metrics" do
    Lockistics.meter("mtest3") do
      sleep 1
    end
    last_total = Lockistics.redis.hgetall("lockistics.mtest3.total")
    last_total.should be_a Hash
    last_invocations = last_total["invocations"].to_i
    Lockistics.meter("mtest3") do
      sleep 3
    end
    last_total = Lockistics.redis.hgetall("lockistics.mtest3.total")
    last_total["invocations"].to_i.should eq last_invocations + 1
    Lockistics.redis.del("lockistics.mtest3.total")
  end

  it "should collect custom metrics" do
    Lockistics.meter("mtest4") do |meter|
      meter.incr "stuffs_done"
      meter.incrby "stuffs_done2", 5
      meter.set_minmax "stuffs_done3", 10
    end
    last_hourly_ts = Lockistics.redis.smembers("lockistics.mtest4.hourlies").last
    last_hourly    = Lockistics.redis.hgetall("lockistics.mtest4.hourly.#{last_hourly_ts}")
    last_hourly["min.stuffs_done3"].to_i.should eq 10
    last_hourly["max.stuffs_done3"].to_i.should eq 10
    last_hourly["stuffs_done2"].to_i.should eq 5
    last_hourly["stuffs_done"].to_i.should eq 1
    Lockistics.meter("mtest4") do |meter|
      meter.incr "stuffs_done"
      meter.incrby "stuffs_done2", 5
      meter.set_minmax "stuffs_done3", 20
    end
    last_hourly_ts = Lockistics.redis.smembers("lockistics.mtest4.hourlies").last
    last_hourly    = Lockistics.redis.hgetall("lockistics.mtest4.hourly.#{last_hourly_ts}")
    last_hourly["min.stuffs_done3"].to_i.should eq 10
    last_hourly["max.stuffs_done3"].to_i.should eq 20
    last_hourly["stuffs_done2"].to_i.should eq 10
    last_hourly["stuffs_done"].to_i.should eq 2
  end

  it "should collect metrics while locking too" do
    Lockistics.meterlock("mtest4") do
      sleep 1
    end
    last_hourly_ts = Lockistics.redis.smembers("lockistics.mtest4.dailies").last
    last_hourly    = Lockistics.redis.hgetall("lockistics.mtest4.dailies.#{last_hourly_ts}")
  end

  it "should know known keys" do
    Lockistics.redis.del("lockistics.known_keys")
    Lockistics.meter("mtest1") {}
    Lockistics.meter("mtest2") {}
    Lockistics.meterlock("mtest3", :wait => false, :raise => false) {}
    Lockistics.lock("mtest4", :wait => false, :raise => false) {}
    Lockistics.known_keys.include?("mtest1").should be_true
    Lockistics.known_keys.include?("mtest2").should be_true
    Lockistics.known_keys.include?("mtest3").should be_true
    Lockistics.known_keys.include?("mtest4").should be_false
  end
end
