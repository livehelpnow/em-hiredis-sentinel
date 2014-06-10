$:.unshift(File.expand_path('../../lib', __FILE__))
require 'em-hiredis-sentinel'
require 'logger'

EM.run {

  EM::Hiredis.logger = Logger.new('output.log')


  redis_sentinel = EM::Hiredis::Client.new('127.0.0.1',6379,nil,nil,
                                                :sentinels => [
                                                    {:host => '127.0.0.1', :port => 26379},
                                                    {:host => '127.0.0.1', :port => 26380},
                                                    {:host => '127.0.0.1', :port => 26381}
                                                ],
                                                :master_name => 'mymaster').connect

  EM.add_periodic_timer(1) {
    puts "Connected: #{redis_sentinel.connected?}"
    response_deferrable = redis_sentinel.get('foo')
    response_deferrable.callback { |value|
      puts value
    }
    response_deferrable.errback { |e|
      puts e
    }
  }
}
