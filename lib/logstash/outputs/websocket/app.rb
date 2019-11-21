# encoding: utf-8
require "logstash/namespace"
require "logstash/outputs/websocket"
require "sinatra/base"
require "rack/handler/ftw" # from ftw
require "ftw/websocket/rack" # from ftw
require "pubsub"
require 'json'

class App < Sinatra::Base
  def initialize(pubsub, filter, logger)
    @pubsub = pubsub
    @logger = logger
	@defaultFilter = filter
  end

  def isAccepted(event,filters)
    accepted = true
    filters.keys.each do |key|
    value = event.get(key)
      filter = filters[key]
      if filter.kind_of?(Array) then
        found = false
        filter.each do |entry|
          if value.match(entry) then
            found = true;
          end
        end
        if accepted && !found then
          accepted = false
          return accepted
        end
      elsif filter.kind_of?(String) then
        if accepted && !value.match(filter) then
          accepted = false
          return accepted
        end
      end
    end
    return accepted
  end

  set :reload_templates, false

  get "/" do
    # TODO(sissel): Support filters/etc.
    ws = ::FTW::WebSocket::Rack.new(env)
    @logger.debug("New websocket client")

    filters = JSON.parse(@defaultFilter)
    ws.each do |payload|
      begin
        filters = JSON.parse(payload)
        @logger.debug("New filter " + payload)
      rescue JSON::ParserError => e
        @logger.debug("New filter parse error " + payload) #TODO remove payload
    end
    stream(:keep_open) do |out|
      @pubsub.subscribe do |event|
        if isAccepted then
          ws.publish(event)
        end
      end # pubsub
    end # stream

    ws.rack_response
  end # get /

end # class LogStash::Outputs::WebSocket::App
