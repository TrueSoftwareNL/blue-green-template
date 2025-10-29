FROM node:24

WORKDIR /app

COPY package.json .
COPY server.js .
COPY healthcheck.sh .
COPY start-application.sh .

RUN yarn install

EXPOSE 3000
HEALTHCHECK --interval=5s --timeout=3s --retries=3 CMD ["./healthcheck.sh"]

CMD ["./start.sh"]
