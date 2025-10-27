FROM node:24-alpine

WORKDIR /app

COPY package.json .
RUN npm install -g yarn
RUN yarn install

COPY server.js .
COPY healthcheck.sh .

EXPOSE 3000

HEALTHCHECK --interval=5s --timeout=3s --retries=3 CMD ["./healthcheck.sh"]

CMD ["yarn", "start"]
