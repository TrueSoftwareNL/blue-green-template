const express = require('express');
const os = require('os');

const app = express();

// Read PORT from environment variable (set by Docker Compose), default to 3000
const PORT = process.env.PORT || 3000;

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

const server = app.listen(PORT, () => {
  console.log(`Server running on port ${PORT} (${ENVIRONMENT} environment)`);
});

// Graceful shutdown — close connections cleanly when Docker stops the container
// Docker sends SIGTERM first, then SIGKILL after timeout (default 10s)
function gracefulShutdown(signal) {
  console.log(`Received ${signal}, shutting down gracefully...`);
  server.close(() => {
    console.log('HTTP server closed');
    process.exit(0);
  });

  // Force exit if graceful shutdown takes too long (5 seconds)
  setTimeout(() => {
    console.error('Graceful shutdown timed out, forcing exit');
    process.exit(1);
  }, 5000);
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));
