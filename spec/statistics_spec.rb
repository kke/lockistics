require File.expand_path('../spec_helper.rb', __FILE__)

describe "Lockistics.statistics" do
  it "should get total metrics" do
    Lockistics.meter("stest1") do
      sleep 1
    end
    stats = Lockistics.statistics("stest1")
    stats.total["max.time"].to_i.should be > 1000
    stats.total["invocations"].to_i.should eq 1
    Lockistics.meter("stest1") do
      sleep 3
    end
    stats = Lockistics.statistics("stest1")
    stats.total["max.time"].to_i.should be > 3000
    stats.total["invocations"].to_i.should eq 2
  end

  it "should get daily metrics" do
    Lockistics.meter("stest2") do
      sleep 1
    end
    stats = Lockistics.statistics("stest2")
    stats.daily.should be_a Array
    stats.daily.first[:time].should be_a Time
  end

  it "should get hourly metrics" do
    Lockistics.meter("stest3") do
      sleep 1
    end
    stats = Lockistics.statistics("stest3")
    stats.hourly.should be_a Array
    stats.hourly.first[:time].should be_a Time
  end
end

