require 'em-hiredis'
require 'em-hiredis-sentinel/client'
require 'em-hiredis-sentinel/base_client'
require 'em-hiredis-sentinel/pubsub_client'

module EventMachine::Hiredis
  class_eval {
    def self.connect_sentinel(options={})
      # Should Return an EM-Hiredis client with added sentinel support
      sentinel_client = EM::Hiredis::Sentinel::Client.new options
      sentinel_client.redis_client
    end
  }
end