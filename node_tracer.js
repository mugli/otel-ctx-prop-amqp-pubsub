const {
  AmqplibInstrumentation,
} = require("@opentelemetry/instrumentation-amqplib");
const { HttpInstrumentation } = require("@opentelemetry/instrumentation-http");
const { NodeSDK } = require("@opentelemetry/sdk-node");
const { ConsoleSpanExporter } = require("@opentelemetry/sdk-trace-node");

process.env["ENABLE_OTEL_INSTRUMENTATION"] =
  process.env["ENABLE_OTEL_INSTRUMENTATION"] ?? "true";

const { diag, DiagConsoleLogger, DiagLogLevel } = require("@opentelemetry/api");

if (process.env["ENABLE_OTEL_INSTRUMENTATION"]) {
  diag.setLogger(new DiagConsoleLogger(), DiagLogLevel.DEBUG);

  const sdk = new NodeSDK({
    serviceName: process.env["SERVICE_NAME"],
    traceExporter: new ConsoleSpanExporter(),
    instrumentations: [new AmqplibInstrumentation(), new HttpInstrumentation()],
  });

  sdk.start();
}
