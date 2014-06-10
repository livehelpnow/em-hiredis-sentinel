module EventMachine::Hiredis
  class Client < BaseClient
    class_eval {
      def pubsub
        @pubsub ||= begin
          PubsubClient.new(@host, @port, @password, @db, @sentinel_options).connect
        end
      end
    }
  end
end