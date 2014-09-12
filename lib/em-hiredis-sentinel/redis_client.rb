require 'em-hiredis'

module EventMachine::Hiredis::Sentinel
  class RedisClient < EventMachine::Hiredis::Client
    alias :super_connect :connect #to ref super's connect

    def initialize(sentinels:[], master_name:'mymaster', db:0, password:nil)
      @master_name = master_name
      @sentinels = _parse_sentinel_options(sentinels)
      #p @sentinels
      raise "Need at least 1 sentinel" if @sentinels.nil? || @sentinels.count < 1
      @sentinels.uniq! {|h| h.values_at(:host, :port) }
      @sentinels.shuffle! #try to randomize

      init_sentinel_client

      super(nil, nil, password, db)
      init_master_client

      #waits for connect to do anything
    end

    #override bc of auto .connect in super
    def pubsub
      #EM::Hiredis.logger.debug("pubsub")
      @pubsub ||= begin
        @with_pubsub = true
        init_master_pubsub_client
        update_master_pubsub_client(@master_client.host, @master_client.port) if @master_client.connected?
        @master_pubsub_client
      end
    end

    def connect(with_pubsub:false)
      @with_pubsub ||= with_pubsub
      try_next_sentinel
      self
    end

    protected

    def init_sentinel_client
      @sentinel_client = EM::Hiredis::Client.new

      @sentinel_client.on(:connected) do
        EM::Hiredis.logger.debug("Connected to sentinel")
        emit(:sentinel_connected)

        EM.next_tick do
          #wait till sentinel connected to init pubsub
          @sentinel_pubsub_client ?
            update_sentinel_pubsub_client(@sentinel_client.host, @sentinel_client.port) :
            init_sentinel_pubsub_client #auto connects

          discover_master unless @master_client.connected?
        end
      end

      @sentinel_client.on(:failed) do
        EM::Hiredis.logger.debug("Failed sentinel")
        @sentinel_client.close_connection
        emit(:sentinel_failed)

        EM.add_timer(0.5) do
          try_next_sentinel
        end
      end

      @sentinel_client.on(:disconnected) do
        EM::Hiredis.logger.debug("Disconnected from sentinel")
        emit(:sentinel_disconnected)
      end
    end

    def init_sentinel_pubsub_client
      @sentinel_pubsub_client = @sentinel_client.pubsub #lazy init, this will auto try connect
      @sentinel_pubsub_client.on(:connected) do
        EM::Hiredis.logger.debug("Connected to sentinel for pubsub")
        emit(:sentinel_pubsub_connected)
      end

       @sentinel_pubsub_client.on(:failed) do
        EM::Hiredis.logger.debug("#{@name} pubsub failed")
        @sentinel_pubsub_client.close_connection
        emit(:sentinel_pubsub_failed)
       end

      @sentinel_pubsub_client.on(:disconnected) do
        EM::Hiredis.logger.debug("Disconnected from sentinel for pubsub")
        emit(:sentinel_pubsub_disconnected)
      end

      watch_sentinel
    end

    def watch_sentinel
      #EM::Hiredis.logger.debug("watch_sentinel")

      #@sentinel_pubsub_client.punsubscribe('*') #in case already subscribe?
      @sentinel_pubsub_client.psubscribe('*') do |channel, message|
        EM::Hiredis.logger.debug("SENTINEL PUBSUB #{channel} #{message}")

        case channel
        when '+switch-master'
          master_name, old_host, old_port, new_host, new_port = message.split(" ")

          if master_name == @master_name
            EM::Hiredis.logger.debug("Failover: #{old_host}:#{old_port} => #{new_host}:#{new_port}")
            update_master_client(new_host, new_port.to_i)
          end

        when '-odown' #TODO necessary?
          type, master_name, host, port = message.split(" ")

          if master_name == @master_name #&& type == 'master' type is always master for odown
            EM::Hiredis.logger.debug("-ODOWN #{connected?}")
            update_master_client(host, port.to_i)
          end
        end
      end
    end

    def init_master_client
      @master_client = self
      @master_client.on(:connected) do
        EM::Hiredis.logger.debug("#{@name} Connected to master")
        @is_master_updating = false

        #TODO confirm is master with ROLE (2.8.12)
        emit(:master_connected)

        EM.next_tick do
          if @with_pubsub
            if @master_pubsub_client
              update_master_pubsub_client(@master_client.host, @master_client.port)
            else
              pubsub
            end
          end

          refresh_sentinels_list #TODO maybe do on sentinel connect
        end
      end

      @master_client.on(:failed) do
        EM::Hiredis.logger.debug("#{@name} failed")
        @is_master_updating = false
        @master_client.close_connection
        emit(:master_failed)
        queue_discover_master
      end

      @master_client.on(:disconnected) do
        EM::Hiredis.logger.debug("#{@name} Disconnected from master")
        emit(:master_disconnected)
      end
    end

    def init_master_pubsub_client
      #EM::Hiredis.logger.debug("init_master_pubsub_client")
      @master_pubsub_client = EM::Hiredis::PubsubClient.new(@master_client.host,
                                                @master_client.port,
                                                @master_client.password,
                                                @master_client.db
                                              )
      @master_pubsub_client.on(:connected) do
        EM::Hiredis.logger.debug("#{@name} Connected to master for pubsub")
        emit(:master_pubsub_connected)
      end

       @master_pubsub_client.on(:failed) do
        EM::Hiredis.logger.debug("#{@name} pubsub failed")
        @master_pubsub_client.close_connection
        emit(:master_pubsub_failed)
       end

      @master_pubsub_client.on(:disconnected) do
        EM::Hiredis.logger.debug("#{@name} Disconnected from master for pubsub")
        emit(:master_pubsub_disconnected)
      end
    end

    def update_sentinel_client(host, port)
      EM::Hiredis.logger.debug("update_sentinel_client #{host}, #{port}")

      @sentinel_client.configure("redis://#{host}:#{port}")

      if @sentinel_client.instance_variable_get(:@connection)
        @sentinel_client.close_connection
        EM.next_tick {
          @sentinel_client.reconnect_connection
        }
      else
        EM::Hiredis.logger.debug("FIRST SENTINEL CONNECT ATTEMPT")
        EM.next_tick {
          @sentinel_client.connect #first time, bc baseclient isnt expecting deferred connecting
        }
      end

    rescue => e
      EM::Hiredis.logger.warn(e)
      EM.next_tick do
        try_next_sentinel
      end
    end

    def update_sentinel_pubsub_client(host, port)
      EM::Hiredis.logger.debug("update_sentinel_pubsub_client #{host}, #{port}")
      @sentinel_pubsub_client.configure("redis://#{host}:#{port}")

      if @sentinel_pubsub_client.instance_variable_get(:@connection)
        @sentinel_pubsub_client.close_connection
        EM.next_tick {
          @sentinel_pubsub_client.reconnect_connection
        }
      else
        EM::Hiredis.logger.debug("FIRST SENTINEL PUBSUB CONNECT ATTEMPT")
        EM.next_tick {
          @sentinel_pubsub_client.connect #first time, bc baseclient isnt expecting deferred connecting
        }
      end

    rescue => e
      EM::Hiredis.logger.warn(e)
    end

    def update_master_client(host, port)
      EM::Hiredis.logger.debug("update_master_client #{host}, #{port}")
      EM::Hiredis.logger.debug("MASTER IS UPDATING") if @is_master_updating
      EM::Hiredis.logger.debug("MASTER IS ALREADY CONNECTED") if @master_client.connected?

      return if @master_client.connected?
      return if @is_master_updating #prevent reupdate, can be updated by discover or sentinel pubsub watching

      @is_master_updating = true

      @master_client.configure("redis://#{host}:#{port}") #@host, @port = host, port

      if @master_client.instance_variable_get(:@connection)
        @master_client.close_connection
        EM.next_tick {
          @master_client.reconnect_connection
        }
      else
        EM::Hiredis.logger.debug("FIRST MASTER CONNECT ATTEMPT")
        EM.next_tick {
          @master_client.super_connect #first time, bc baseclient isnt expecting deferred connecting
        }
      end

      rescue => e
        EM::Hiredis.logger.warn(e)
        @is_master_updating = false
        queue_discover_master
    end

    def update_master_pubsub_client(host, port)
      EM::Hiredis.logger.debug("update_master_pubsub_client #{host}, #{port}")
      @master_pubsub_client.configure("redis://#{host}:#{port}")

      if @master_pubsub_client.instance_variable_get(:@connection)
        @master_pubsub_client.close_connection
        EM.next_tick {
          @master_pubsub_client.reconnect_connection
        }
      else
        EM::Hiredis.logger.debug("FIRST MASTER PUBSUB CONNECT ATTEMPT")
        EM.next_tick {
          @master_pubsub_client.connect #first time, bc baseclient isnt expecting deferred connecting
        }
      end
    rescue => e
      EM::Hiredis.logger.warn(e)
    end

    def try_next_sentinel
      #EM::Hiredis.logger.debug("try_next_sentinel")
      s = @sentinels.shift
      @sentinels.push s
      s = @sentinels.first
      update_sentinel_client(s[:host], s[:port])
    end

    def queue_discover_master
      EM.add_timer(0.5) {
        discover_master
      }
    end

    def discover_master
      EM::Hiredis.logger.debug("discover_master")

      if @sentinel_client.connected?
        response_deferrable = @sentinel_client.sentinel("get-master-addr-by-name", @master_name)

        response_deferrable.callback do |value|
          EM::Hiredis.logger.debug("discover_master callback")
          master_host, master_port = value
          EM::Hiredis.logger.debug("returned #{master_host} #{master_port}")
          if master_host && master_port #TODO better check, seems either insufficient or unnecessary
            update_master_client(master_host, master_port.to_i)
          else
            EM::Hiredis.logger.debug("discover_master trying again")
            queue_discover_master
          end
        end

        response_deferrable.errback do |e|
          EM::Hiredis.logger.WARN("discover_master error")
          queue_discover_master
        end

      end
    end

    def refresh_sentinels_list
      response_deferrable = @sentinel_client.sentinel("sentinels", @master_name)

      response_deferrable.callback do |sentinels|
        sentinels.each do |s|
          @sentinels << {:host => s[3], :port => s[5]} #TODO will break if order changes
        end

        @sentinels.uniq! {|h| h.values_at(:host, :port) }
      end
    end

    private

    def _parse_sentinel_options(options)
      ret = []

      options.each do |o|
        o = o[:url] if o.is_a?(Hash) && o.key?(:url)

        if o.is_a?(String)
            #URI requires scheme
            o = o.prepend('redis://') if !o.include? '://'
            o = URI.parse(o)
        end

        ret << { :host => o.host, :port => o.port || 26379 }
      end

      ret
    end
  end
end
