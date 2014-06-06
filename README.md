# Em::Hiredis::Sentinel

Sentinel Support for em-hiredis. Currently this gem does not fully monkey patch the em-hiredis gem in place.

## Installation

Add this line to your application's Gemfile:

    gem 'em-hiredis-sentinel'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install em-hiredis-sentinel

## Usage

    require 'em-hiredis-sentinel'
    redis = EM::Hiredis.connect_sentinel(:master_name => 'mymaster',
                                         :sentinels => [
                                             {:host => '127.0.0.1', :port => 26379},
                                             {:host => '127.0.0.1', :port => 26380},
                                             {:host => '127.0.0.1', :port => 26381}
                                         ],
                                         :host => '127.0.0.1',
                                         :port => 6379)

connect_sentinel will return an instance of EM::Hiredis which will fail over through messages from the sentinels.


## Contributing

1. Fork it ( https://github.com/[my-github-username]/em-hiredis-sentinel/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## TODO

1. Add UNix domain sockets
2. Full password support
3. Add RSpec tests
4. Fully monkey patch em-hiredis to use in place. (Like redis-sentinel)