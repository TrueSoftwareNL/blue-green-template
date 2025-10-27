#!/bin/sh
set -e

if curl -fs http://localhost:3000/health | grep -q "healthy"; then
  exit 0
else
  exit 1
fi
