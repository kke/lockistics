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
 - Minimum and maximum memory growth (using OS gem)
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
    config.expire               = 300  # seconds
    config.sleep                = 0.5  # seconds to sleep between retries
    config.retries              = 10   # retry times
    config.raise                = true # raise Lockistics::TimeoutException when lock fails
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

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
