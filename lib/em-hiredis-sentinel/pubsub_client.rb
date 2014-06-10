module EventMachine::Hiredis
  class PubsubClient < BaseClient
    class_eval {
      def initialize(host='localhost', port='6379', password=nil, db=nil, sentinel_options={})
        puts "Initializing with sentinel: #{sentinel_options}"
        @subs, @psubs = [], []
        @pubsub_defs = Hash.new { |h,k| h[k] = [] }
        super
      end
    }
  end
end