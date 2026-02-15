#!/bin/bash
# Application start script
# Usage: ./start.sh
# Runs the Express.js application via yarn
# Exit codes: 0=clean shutdown, 1=startup failure
set -e

yarn start
