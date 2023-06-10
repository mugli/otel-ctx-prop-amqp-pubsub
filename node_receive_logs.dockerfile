FROM node:20
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY node_tracer.js .
COPY node_receive_logs.js .
CMD [ "node", "node_receive_logs.js" ]
