$:.unshift(File.expand_path('../../lib', __FILE__))
require 'em-hiredis-sentinel'
require 'logger'

EM.run {

  EM::Hiredis.logger = Logger.new('output.log')


  redis_sentinel = EM::Hiredis.connect_sentinel(:master_name => 'mymaster',
                                                :sentinels => [
                                                    {:host => '10.177.137.115', :port => 26379},
                                                    {:host => '10.208.25.162', :port => 26379},
                                                    {:host => '10.178.14.213', :port => 26379}
                                                ],
                                                :host => '10.210.35.226',
                                                :port => 6379)

  redis_sentinel.pubsub.subscribe('foo') { |msg|
    puts msg
  }
}
