# OpenTelemetry context propagation differences for AMQP with Ruby (bunny) vs Node.js (amqplib) auto-instrumentation

This is an example repository that demonstrates that:

- the **`bunny` instrumentation (in Ruby)** works as expected on the producer side,
- the **`bunny` instrumentation (in Ruby)** loses context and cannot propagate further after **the consumer** receives messages; it also changes the trace-id,
- but the **`amqplib` instrumentation (in Node.js)** behaves as expected on the consumer side.

Corresponding issue: https://github.com/open-telemetry/opentelemetry-ruby-contrib/issues/523

**Problem 1: losing context**

`bunny` instrumentation loses context **on the consumer-side** and cannot propagate `baggage` and `tracestate` headers.

**Problem 2: not maintaining trace-id**

Additionally, the `bunny` instrumentation (in Ruby) creates **a new trace-id on the consumer-side**, but the `amqplib` instrumentation maintains trace-id too.

_(However, [this discussion](https://github.com/open-telemetry/opentelemetry-ruby/discussions/1098#discussioncomment-4874651) mentions that this is not a bug and follows batch-receiving semantics for message processing according to OpenTelemetry specs. The point of this demo is to show that with the same configuration `amqplib` instrumentation works differently (and matches expectations), where both of the instrumentation libs are OpenTelemetry provided.)_

## Message and HTTP request flow

![setup](setup.svg)

## Instrumentations used

- `ruby_emit_logs` service:
  - `OpenTelemetry::Instrumentation::Bunny` **(0.20.1)**
- `ruby_receive_logs` service:
  - `OpenTelemetry::Instrumentation::Bunny` **(0.20.1)**
  - `OpenTelemetry::Instrumentation::Net::HTTP`
- `node_receive_logs` service:
  - `@opentelemetry/instrumentation-amqplib`
  - `@opentelemetry/instrumentation-http`

## Run

```sh
make run
```

_(waits a few seconds to start because of the rabbitmq healthcheck)_

This will start everything using `docker-compose`, but will only show logs from:

- the `ruby_emit_logs` container that produces the messages at the beginning
- the `ruby_receive_logs` container that gets the messages with `ruby.info` routing key, and sends a HTTP get request to `http_logger`
- the `http_logger` container that gets HTTP requests at the end of the flow shown in the above diagram.

> To turn on all the logs (really verbose), run `docker-compose up` instead of `make run`

## 🕵️‍♂️ Steps to notice

1. `ruby_emit_logs` publishes messages with the following headers:

```
headers = {
  'baggage' => 'userId=alice,serverNode=DF%2028,isProduction=false',
  'tracestate' => 'rojo=00f067aa0ba902b7,congo=t61rcWkgMzE'
}
```

Because it is instrumented, it also adds a `traceparent` header to the messages.

The logs show them all:

```
[x] Sent Hello! to routing_key: ruby.info with headers:
{"baggage"=>"userId=alice,serverNode=DF%2028,isProduction=false",
"tracestate"=>"rojo=00f067aa0ba902b7,congo=t61rcWkgMzE",
"traceparent"=>"00-cbcf4086d64bd4e71486635802602cc6-d2a8522bb3b89223-01"}


[x] Sent Hello! to routing_key: node.info with headers:
{"baggage"=>"userId=alice,serverNode=DF%2028,isProduction=false",
"tracestate"=>"rojo=00f067aa0ba902b7,congo=t61rcWkgMzE",
"traceparent"=>"00-1235191f6dbde680638ab65f2cc439f5-f7100ed601529884-01"}

```

👉 Notice:

- The trace-id going to **ruby** subscriber is: `cbcf4086d64bd4e71486635802602cc6`
- The trace-id going to **node** subscriber is: `1235191f6dbde680638ab65f2cc439f5`
- Both are carrying the same `baggage` and `tracestate` headers.

2. `ruby_receive_logs` receives the message routed to it, and logs (_shown partially here_):

```
[x] body: Hello!,

_properties: {

:headers=>{"baggage"=>"userId=alice,serverNode=DF%2028,isProduction=false",
 "tracestate"=>"rojo=00f067aa0ba902b7,congo=t61rcWkgMzE",
 "traceparent"=>"00-cbcf4086d64bd4e71486635802602cc6-d2a8522bb3b89223-01"},

:tracer_receive_headers=>{"traceparent"=>"00-99275a96bfeeddae14b33b4b30402b1e-9d4280476fc5ec2a-01"}}
```

👉 Notice:

- The consumer receives all the headers sent from the producer.
- Additionally, the `bunny` instrumentation adds a new `tracer_receive_headers` item in the message property, which changes traceparent.

> The issue (https://github.com/open-telemetry/opentelemetry-ruby-contrib/issues/523) mentions the code location where this property is being added by `OpenTelemetry::Instrumentation::Bunny`.

**🐞 From this point the `bunny` instrumentation sets this new trace-id `99275a96bfeeddae14b33b4b30402b1e` from the `tracer_receive_headers` -> `traceparent` property instead of the original message headers in the span context. It will also lose the `tracestate` and `baggage` contexts in the child span as it makes an HTTP request.**

3. Both `ruby_receive_logs` and `node_receive_logs` consumers send HTTP GET requests to `http_logger` service every time they receive a message.

4. `http_logger` service gets HTTP requests from:

- `ruby_receive_logs` and logs:

```
==== GET /ruby_receive_logs
> Headers
{
  'accept-encoding': 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
  accept: '*/*',
  'user-agent': 'Ruby',
  host: 'http_logger:3000',
  traceparent: '00-99275a96bfeeddae14b33b4b30402b1e-4b157062d19f31a5-01'
}
```

🐞 Notice that we don't have contexts propagated here from step 1.

❓ Notice that we have a new trace-id `99275a96bfeeddae14b33b4b30402b1e` created by the `bunny` instrumentation.

- `node_receive_logs` and logs:

```
==== GET /node_receive_logs
> Headers
{
  traceparent: '00-1235191f6dbde680638ab65f2cc439f5-ff3f75fc67461b8d-01',
  tracestate: 'rojo=00f067aa0ba902b7,congo=t61rcWkgMzE',
  baggage: 'userId=alice,serverNode=DF%2028,isProduction=false',
  host: 'http_logger:3000',
  connection: 'keep-alive'
}
```

✅ Notice that we have all the contexts propagated here from step 1.

✅ Notice that we have the same trace-id sent to `node_receive_logs` in step 1: `1235191f6dbde680638ab65f2cc439f5`.
