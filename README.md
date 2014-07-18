# Em::Hiredis::Sentinel

Sentinel Support for em-hiredis.

## Installation

Add this line to your application's Gemfile:

    gem 'em-hiredis-sentinel'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install em-hiredis-sentinel

## Usage

    require 'em-hiredis-sentinel'
    EM.run do
      redis = EM::Hiredis::Sentinel::RedisClient.new(sentinels:[
                              'redis://sentinel1.example.net',
                              'xyz://sentinel2.example.net:26378',
                              {host:'sentinel3.example.net'},
                              {host:'sentinel4.example.net', port:26380},
                              {url:'blah://sentinel5.example.net:26381'},
                              {url:'ignored://sentinel6.example.net'}
                            ],
                            master_name:'mymaster'
                          )
      redis.connect
      counter = 0
      t = nil

      redis.pubsub.on(:connected) do
        p "connect callback"

        t = EM.add_periodic_timer(2) do
          counter += 1
          redis.pubsub.publish("test", "test-#{counter}")
        end
      end

      redis.pubsub.on(:disconnected) do
        p "disconnect callback"
        t.cancel
      end

    end


## Contributing

1. Fork it ( https://github.com/[my-github-username]/em-hiredis-sentinel/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## TODO

1. Add RSpec tests