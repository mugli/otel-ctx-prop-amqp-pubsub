FROM node:20
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY http_logger.js ./
EXPOSE 3000
CMD ["node", "http_logger.js"]
