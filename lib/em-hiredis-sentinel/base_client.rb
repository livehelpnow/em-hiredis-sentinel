module EventMachine::Hiredis
  class BaseClient
    class_eval {
      attr_reader :sentinel_options

      def initialize_with_sentinel(host = 'localhost', port = 6379, password = nil, db = nil, sentinel_options={})
        
        initialize_without_sentinel(host,port,password,db)
        if sentinel_options.nil? || sentinel_options.empty?
          return
        end

        @sentinel_options = sentinel_options.dup
        @master_name = @sentinel_options[:master_name]
        @sentinels_options = _parse_sentinel_options(@sentinel_options[:sentinels])

        @current_sentinel = EM::Hiredis::Client.new(@sentinels_options[0][:host],@sentinels_options[0][:port]).connect
        @current_sentinel.on(:disconnected) {
          EM::Hiredis.logger.info('Sentinel Failed')
          try_next_sentinel
        }

        #discover_master
        watch_sentinel
        
      end

      alias initialize_without_sentinel initialize
      alias initialize initialize_with_sentinel

      def watch_sentinel
        pubsub = @current_sentinel.pubsub
        pubsub.punsubscribe('*')
        pubsub.psubscribe('*')
        pubsub.on(:pmessage) { |pattern, channel, message|
          next if channel != '+switch-master'

          master_name, old_host, old_port, new_host, new_port = message.split(" ")

          next if master_name != @master_name
          EM::Hiredis.logger.info("Failover: #{old_host}:#{old_port} => #{new_host}:#{new_port}")
          close_connection
          @host, @port = new_host,new_port.to_i
          reconnect_connection
        }
      end

      def try_next_sentinel

        sentinel_options = @sentinels_options.shift
        @sentinels_options.push sentinel_options

        EM::Hiredis.logger.info("Trying next sentinel: #{sentinel_options[:host]}:#{sentinel_options[:port]}")
        @current_sentinel.close_connection
        @current_sentinel.configure("redis://#{sentinel_options[:host]}:#{sentinel_options[:port]}")
        @current_sentinel.reconnect_connection
        unless @switching_sentinels
          @switching_sentinels = true
          @sentinel_timer = EM.add_periodic_timer(1) {
            if @current_sentinel.connected?
              @switching_sentinels = false
              @sentinel_timer.cancel
            else
              try_next_sentinel
            end
          }
        end
      end

      def discover_master
        response_deferrable = @current_sentinel.sentinel("get-master-addr-by-name", @master_name)
        response_deferrable.callback { |value|
          master_host, master_port = value

          if master_host && master_port

            @host, @port = master_host,master_port.to_i
            reconnect_connection
            refresh_sentinels_list
          else
            EM.next_tick {
              self.discover_master
            }
          end
        }
        response_deferrable.errback { |e|
          EM.next_tick {
            self.discover_master
          }
        }
      end

      def refresh_sentinels_list
        response_deferrable = @current_sentinel.sentinel("sentinels", @master_name)
        response_deferrable.callback { |sentinels|
          sentinels.each { |sentinel|
            @sentinels_options << {:host => sentinel[3], :port => sentinel[5]}
            @sentinels_options.uniq! {|h| h.values_at(:host, :port) }
          }
        }
        response_deferrable.errback { |e|
          try_next_sentinel
        }
      end

      private

      def _parse_sentinel_options(options)
        return if options.nil?

        sentinel_options = []
        options.each do |opts|
          opts = opts[:url] if opts.is_a?(Hash) && opts.key?(:url)
          case opts
            when Hash
              sentinel_options << opts
            else
              uri = URI.parse(opts)
              sentinel_options << {
                  :host => uri.host,
                  :port => uri.port
              }
          end
        end
        sentinel_options
      end
    }    
  end
end