#!/usr/bin/env bash
set -euo pipefail

IMAGE=tic-tac-toe:local
CONTAINER=tic_test_local
PORT=8080

echo "Building Docker image..."
docker build -t ${IMAGE} .

echo "Starting container..."
docker run -d --name ${CONTAINER} -p ${PORT}:8080 ${IMAGE}

# give it a moment
sleep 2

echo "Fetching HTTP headers..."
headers=$(curl -sI http://localhost:${PORT} || true)
echo "$headers"

# Basic header checks
echo
echo "Checking for security headers..."
for h in "Content-Security-Policy" "Strict-Transport-Security" "X-Frame-Options" "X-Content-Type-Options" "Referrer-Policy"; do
  if echo "$headers" | grep -i "$h" >/dev/null; then
    echo "[OK] $h present"
  else
    echo "[WARN] $h missing"
  fi
done

# Cleanup
echo
echo "Cleaning up..."
docker rm -f ${CONTAINER} >/dev/null 2>&1 || true
docker rmi ${IMAGE} >/dev/null 2>&1 || true

echo "Done."
