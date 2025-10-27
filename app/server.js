const express = require('express');
const os = require('os');

const app = express();
const PORT = 3000;

// Get environment from environment variable, default to 'unknown'
const ENVIRONMENT = process.env.APP_ENV || 'unknown';

app.get('/ping', (req, res) => {
  res.json({
    msg: 'pong',
    host: os.hostname(),
    environment: ENVIRONMENT
  });
});

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    host: os.hostname(),
    environment: ENVIRONMENT,
    timestamp: new Date().toISOString()
  });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT} (${ENVIRONMENT} environment)`);
});
