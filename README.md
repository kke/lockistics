# Lockistics

Lockistics is basically a distributed mutex on Redis with statistics collecting included.

The likely use case for locking would be something like a Raketask that you don't want running multiple instances at once.

The likely use case for the statistics part would be that you want to know how often something is being called or if a certain Raketask has been run today or not. You can also use it to find memory leaks or slow methods, kind of private NewRelic with zero features.

## Installation

Add this line to your application's Gemfile:

    gem 'lockistics'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install lockistics

#### Redis

Notice that you need a Redis v2.6.2+ as this gem uses LUA for race condition safe lock acquiring and min/max setting

## Usage

You can use both parts separately if you just want to collect statistics or to just do simple locking.

Total, daily and hourly metrics you get for each key are:

 - Number of locks
 - Number of times having to wait for lock
 - Number of failed locking attempts
 - Minimum and maximum duration
 - Minimum and maximum memory growth (using OS gem, only when :meter_rss is set to true)
 - Arbitary metrics you add during execution (more on this in examples)

## Why?

Convenience mostly. There are redis-locking gems and some quite complex statistics modules, this does both with minimum dependencies, easy usage and Ruby 1.8.7 support.

## Examples

#### Configure the gem

These are the default settings :

```ruby
  Lockistics.configure do |config|
    config.redis                = Redis.new
    config.namespace            = "lockistics"
    config.expire               = 300   # seconds
    config.sleep                = 0.5   # seconds to sleep between retries
    config.retries              = 10    # retry times
    config.raise                = true  # raise Lockistics::TimeoutException when lock fails
    config.pass_through         = false # don't do anything, let everything pass through
  end
```

#### Getting and using a lock

```ruby
  # Get a lock, do what you must, release lock. No statistics collection.
  Lockistics.lock("generate-stuff-raketask") do
    doing_some_heavy_stuff
  end
```

```ruby
  # Some raketask that you don't want to run multiple times at once :
  namespace :raketask
    desc 'Generate stuff'
    task :generate_stuff do
      return nil unless Lockistics.lock("generate-stuff", :wait => false)
      ...
    end
  end
```

```ruby
  # Handle exception when you fail to acquire a lock in time:
  begin
    Lockistics.lock("stuff") do
      ...
    end
  rescue Lockistics::Timeout
    ...
  end
```

```ruby
  # Don't raise exceptions
  Lockistics.lock("stuff", :raise => false) do
    ...
  end
```

#### Statistics collection without locking

It works exactly like the locking, but the method is `meter`.

```ruby
  # Perform something, statistics will be collected behind the scenes.
  Lockistics.meter("generate-stuff-raketask") do
    doing_some_stuff
  end
```

```ruby
  # Adding custom metrics
  Lockistics.meter("generate-stuff") do |meter|
    results = do_stuff
    if results.empty?
      meter.incr "empty_results"
    else
      meter.incrby "stuffs_done", results.size
    end
  end
```

#### Statistics collection with locking

It works exactly like the above, but the method is `meterlock`.

```ruby
  # Adding custom metrics
  Lockistics.meterlock("generate-stuff", :raise => false) do |meter|
    results = do_stuff
    if results.empty?
      meter.incr "empty_results"
    else
      # Sets min and/or max for a key (min.stuffs_done + max.stuffs_done)
      # Only sets if value is minimum or maximum for the periods.
      meter.set_minmax "stuffs_done", results.size
    end
  end
```

#### Wrapping instance methods of a class

This is still experimental and I'm not quite happy with the implementation.

```ruby
  class SomeClass
    include Lockistics::Meterable
    meter :some_instance_method
    # or:
    meter :all, :except => :not_this_method

    def some_instance_method
      do_something
    end

    def not_this_method
      do_something
    end
  end
```

Now each call to `some_instance_method` should be wrapped inside a meter
block and the key name is "someclass_some_instance_method".

The include and meter commands should be placed above any method
definitions in the file. Prettier implementation would be appreciated,
preferably one that would work with class methods also.

#### Getting the statistics out

You can query statistics for locking/metering keys.

```ruby
  stats = Lockistics.statistics('generate'stuff')
  # Get the last run
  stats.last_run
   => Mon May 19 16:38:52 +0300 2014
  # Get totals:
  stats.total
   => {"invocations" => 50, "lock-timeouts" => 1,
       "max.stuffs-generated" => 10, "max_rss" => 400 ..}
  stats.daily
   => [{:time => #<Time..> "invocations" => 50, "lock-timeouts" => 1,
       "max.stuffs-generated" => 10, "max_rss" => 400 ..}, {..}]
  stats.hourly
   => [{:time => #<Time..> "invocations" => 50, "lock-timeouts" => 1,
       "max.stuffs-generated" => 10, "max_rss" => 400 ..}, {..}]
  stats.all
   => { :daily => [...], :hourly => [...], :total => {...},
        :last_run:time => #<Time..>}
```

## Storage

- All keys are prefixed with the `configuration.namespace`
- namespace.KEY_NAME.lock for lock
- namespace.KEY_NAME.dailies is a sorted set with timestamps
- namespace.KEY_NAME.daily.TIMESTAMP is a hash with keys like "invocations", "max.time"
- same goes for hourlies (but with hourly + hourlies in the key)
- namespace.KEY_NAME.total has all time stats for the key
- namespace.known_keys is a sorted set of known keys

Storage amount requirements are not that large since there's only incremental/min_max counters maximum once for each hour, each day and the total. My guess is max 10kb per day per key, so even with actions to a million keys a day you would still have inrease of maybe 10 megabytes a day. In a future version there can be an option to set expiration on darily/hourly hashes so that old data disappears automatically.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
