#!/usr/bin/env node

process.env["SERVICE_NAME"] =
  process.env["SERVICE_NAME"] ?? "node_receive_logs";

// ========================================================================
// Begin instrumentation
require("./node_tracer");
// End instrumentation
// ========================================================================

// ========================================================================
// Start subscriber

const amqp = require("amqplib");
const http = require("http");

async function connectAndConsume() {
  const amqpUrl = process.env["RABBITMQ_URL"] ?? "amqp://localhost";
  const connection = await amqp.connect(amqpUrl);
  const channel = await connection.createChannel();

  const exchange = "topic_logs";
  await channel.assertExchange(exchange, "topic", { durable: true });

  const { queue } = await channel.assertQueue("node", {
    exclusive: false,
    durable: true,
  });

  console.log(" [*] Waiting for logs. To exit press CTRL+C");

  await channel.bindQueue(queue, exchange, "node.info");

  await channel.consume(
    queue,
    (msg) => {
      const headers = msg?.properties.headers;
      console.log(
        ` [x] body: ${msg?.content.toString()}, headers: ${JSON.stringify(
          headers
        )}`
      );
      httpGet();
    },
    { noAck: true }
  );
}

function httpGet() {
  let url = process.env["HTTP_LOGGER_URL"];

  if (url) {
    url = `${url}/${process.env["SERVICE_NAME"]}`;
    http.get(url).on("error", (err) => {
      console.error(`Error HTTP GET ${url}: `, err.message);
    });
  }
}

connectAndConsume().catch((error) => {
  console.error(error);
  process.exit(1);
});

// End subscriber
// ========================================================================
