module EventMachine::Hiredis
  class PubsubClient < BaseClient
    class_eval {
      def initialize(host='localhost', port='6379', password=nil, db=0)
        @subs, @psubs = [], []
        @pubsub_defs = Hash.new { |h,k| h[k] = [] }

        @sub_callbacks = Hash.new { |h, k| h[k] = [] }
        @psub_callbacks = Hash.new { |h, k| h[k] = [] }

        super
      end

      def connect
        # Resubsubscribe to channels on reconnect
        on(:reconnected) {
          raw_send_command(:subscribe, @subs) if @subs.any?
          raw_send_command(:psubscribe, @psubs) if @psubs.any?
        }
        super
      end
    }
  end
end