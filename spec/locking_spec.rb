require File.expand_path('../spec_helper.rb', __FILE__)

describe "Lockistics.lock" do
  it "should only allow one instance to lock something at once" do
    lock1 = Lockistics.lock("ltest1", :wait => false, :raise => false, :expire => 100)
    sleep 1
    lock2 = Lockistics.lock("ltest1", :wait => false, :raise => false, :expire => 100)
    lock1.should be_true
    lock2.should be_false
    Lockistics.release("ltest1")
    lock2 = Lockistics.lock("ltest1", :wait => false, :raise => false, :expire => 100)
    lock2.should be_true
  end

  it "should allow locking again after block mode" do
    lock1_ok = false
    lock2_ok = false
    lock1 = Lockistics.lock("ltest1", :wait => false, :raise => false, :expire => 100) do
      lock1_ok = true
      sleep 1
    end
    lock2 = Lockistics.lock("ltest1", :wait => false, :raise => false, :expire => 100) do
      lock2_ok = true
    end
    lock1_ok.should be_true
    lock2_ok.should be_true
    Lockistics.release("ltest1")
  end

  it "should allow locking different keys at once" do
    lock1_ok = false
    lock2_ok = false
    lock1 = Lockistics.lock("ltest1", :wait => false, :raise => false, :expire => 100) do
      lock1_ok = true
      lock2 = Lockistics.lock("ltest2", :wait => false, :raise => false, :expire => 100) do
        lock2_ok = true
      end
    end
    lock1_ok.should be_true
    lock2_ok.should be_true
    Lockistics.release("ltest1")
    Lockistics.release("ltest2")
  end

  it "should raise when lock not acquired" do
    lock1_ok = false
    lock2_ok = false
    lock1 = Lockistics.lock("ltest1", :wait => false, :raise => false, :expire => 100)
    expect {Lockistics.lock("ltest1")}.to raise_error(Lockistics::LockTimeout)
    Lockistics.release("ltest1")
    Lockistics.release("ltest2")
  end

  it "should not collect metrics when locking only" do
    Lockistics.lock("ltest1", :wait => false, :raise => false, :expire => 100) do
      #
    end
    stats = Lockistics.statistics("ltest1")
    Lockistics.redis.keys(Lockistics.configuration.namespace + ".ltest1*").should be_empty
    stats.daily.should be_empty
  end
end
