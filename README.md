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
    redis_sentinel = EM::Hiredis::Client.new('127.0.0.1',6379,nil,nil,
                                                :sentinels => [
                                                    {:host => '127.0.0.1', :port => 26379},
                                                    {:host => '127.0.0.1', :port => 26380},
                                                    {:host => '127.0.0.1', :port => 26381}
                                                ],
                                                :master_name => 'mymaster').connect


## Contributing

1. Fork it ( https://github.com/[my-github-username]/em-hiredis-sentinel/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## TODO

1. Add RSpec tests