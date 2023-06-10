#!/usr/bin/env ruby

require 'opentelemetry/sdk'
require 'opentelemetry-instrumentation-bunny'
require 'opentelemetry-instrumentation-net_http'
require 'bunny'
require 'net/http'

ENV['SERVICE_NAME'] ||= 'ruby_receive_logs'

# ========================================================================
# Begin instrumentation

ENV['OTEL_TRACES_EXPORTER'] ||= 'none'
ENV['ENABLE_OTEL_INSTRUMENTATION'] ||= 'true'

if ENV['ENABLE_OTEL_INSTRUMENTATION']
  OpenTelemetry::SDK.configure do |c|
    c.service_name = ENV['SERVICE_NAME']
    c.use 'OpenTelemetry::Instrumentation::Bunny'
    c.use 'OpenTelemetry::Instrumentation::Net::HTTP'
  end
end


# End instrumentation
# ========================================================================


# ========================================================================
# Start subscriber


def http_get()
  begin
    uri = ENV['HTTP_LOGGER_URL']
    if uri
      uri = uri + '/' + ENV['SERVICE_NAME']
      Net::HTTP.get(URI(uri))
    end
  rescue StandardError => e
    puts "Error HTTP GET #{uri}: #{e.message}"
  end
end

ENV['RABBITMQ_URL'] ||= 'amqp://localhost'

connection = Bunny.new
connection.start

channel = connection.create_channel
exchange = channel.topic('topic_logs', {durable: true})
queue = channel.queue('ruby', {exclusive: false, durable: true} )
queue.bind(exchange, routing_key: 'ruby.info')


puts ' [*] Waiting for logs. To exit press CTRL+C'

begin
  # block: true is only used to keep the main thread
  # alive. Please avoid using it in real world applications.
  queue.subscribe(block: true) do |_delivery_info, _properties, body|
    puts " [x] body: #{body}, _properties: #{_properties}"
    STDOUT.flush
    http_get
  end

rescue Interrupt => _
  channel.close
  connection.close
end

# End subscriber
# ========================================================================