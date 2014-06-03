require File.expand_path('../spec_helper.rb', __FILE__)

class MeterableTest

  include Lockistics::Meterable

  meter :all, :except => [
    :do_not_meter_this_instance_method,
    :meter_this_instance_method_too
  ]
  meter :meter_this_instance_method_too

  def self.meter_this_class
    "ok_class"
  end

  def meter_this_instance_method
    "ok"
  end

  def meter_this_instance_method_too
    "ok"
  end

  def do_not_meter_this_instance_method
    "ok"
  end

end

describe "Lockistics.meterable" do
  it "should wrap desired methods into meters" do
    MeterableTest.new.meter_this_instance_method.should eq "ok"
    last_total = Lockistics.redis.hgetall("lockistics.meterabletest_meter_this_instance_method.total")
    last_total.should_not be_empty
    MeterableTest.new.meter_this_instance_method_too.should eq "ok"
    last_total = Lockistics.redis.hgetall("lockistics.meterabletest_meter_this_instance_method_too.total")
    last_total.should_not be_empty
    MeterableTest.new.do_not_meter_this_instance_method.should eq "ok"
    last_total = Lockistics.redis.hgetall("lockistics.meterabletest_do_not_meter_this_instance_method.total")
    last_total.should be_empty
  end
end
