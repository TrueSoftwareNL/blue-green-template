FROM node:18-alpine

WORKDIR /app

COPY package.json .

RUN npm install

COPY server.js .

EXPOSE 3000

HEALTHCHECK --interval=5s --timeout=3s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => { let data = ''; r.on('data', (chunk) => data += chunk); r.on('end', () => { try { const json = JSON.parse(data); process.exit(json.status === 'healthy' ? 0 : 1); } catch(e) { process.exit(1); } }); }).on('error', () => process.exit(1));"

CMD ["npm", "start"]
