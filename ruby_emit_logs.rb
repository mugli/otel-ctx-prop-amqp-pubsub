#!/usr/bin/env ruby

require 'opentelemetry/sdk'
require 'opentelemetry-instrumentation-bunny'
require 'bunny'

ENV['SERVICE_NAME'] ||= 'ruby_emit_logs'

# ========================================================================
# Begin instrumentation

ENV['OTEL_TRACES_EXPORTER'] ||= 'none'
ENV['ENABLE_OTEL_INSTRUMENTATION'] ||= 'true'

if ENV['ENABLE_OTEL_INSTRUMENTATION']
  OpenTelemetry::SDK.configure do |c|
    c.service_name = ENV['SERVICE_NAME']
    c.use 'OpenTelemetry::Instrumentation::Bunny'
  end
end

# End instrumentation
# ========================================================================



# ========================================================================
# Start publisher

ENV['RABBITMQ_URL'] ||= 'amqp://localhost'

connection = Bunny.new
connection.start

channel = connection.create_channel
exchange = channel.topic('topic_logs', {durable: true})

routing_keys = ['ruby.info', 'node.info']


headers = {
  'baggage' => 'userId=alice,serverNode=DF%2028,isProduction=false',
  'tracestate' => 'rojo=00f067aa0ba902b7,congo=t61rcWkgMzE'
}

message = 'Hello!'

puts ' [*] Sending logs. To exit press CTRL+C'

begin
  loop do
    routing_keys.each do |routing_key|
      exchange.publish(message, {routing_key: routing_key, headers: headers })
      puts " [x] Sent #{message} to routing_key: #{routing_key} with headers: #{headers}\n\n"
      STDOUT.flush
    end
    sleep(2)
  end

rescue Interrupt => _
  channel.close
  connection.close
end

# End publisher
# ========================================================================