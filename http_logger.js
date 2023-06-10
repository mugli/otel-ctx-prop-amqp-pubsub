const http = require("http");
const server = http.createServer();

process.on("SIGINT", () => {
  process.exit(0);
});

console.log(` [*] HTTP LOGGER LISTENING ON PORT 3000`);
server
  .on("request", (request, response) => {
    const body = [];
    request
      .on("data", (chunk) => {
        body.push(chunk);
      })
      .on("end", () => {
        console.log(`==== ${request.method} ${request.url}`);
        console.log("> Headers");
        console.log(request.headers);

        if (body.length) {
          console.log("> Body");
          console.log(Buffer.concat(body).toString());
        }

        response.end();
      });
  })
  .listen(3000, "0.0.0.0");
