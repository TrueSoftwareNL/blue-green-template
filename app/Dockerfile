FROM node:24

WORKDIR /app

COPY package.json .
COPY server.js .
COPY healthcheck.sh .
COPY start.sh .

RUN yarn install

# Make scripts executable for HEALTHCHECK and CMD
RUN chmod +x healthcheck.sh start.sh

EXPOSE 3000
HEALTHCHECK --interval=5s --timeout=3s --retries=3 CMD ["./healthcheck.sh"]

CMD ["./start.sh"]
