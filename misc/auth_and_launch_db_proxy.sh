#!/usr/bin/env bash
set -euo pipefail

# Usage: ./gcsql_min_check.sh <UNIQNAME>
# Example: ./gcsql_min_check.sh jtdiaz
# What it does:
# 1) Checks that all required libraries (gcloud, cloud-sql-proxy, and mysql) are installed
# 2) Runs: gcloud auth application-default login 
#   a) Authenticates you with your UMich Email
# 3) Starts: cloud-sql-proxy --auto-iam-authn thebuilders:us-central1:db
#   a) Use OAuth (your UMich Email) as short lived password to authenticate to DB
# 4) Connects: mysql --host 127.0.0.1 --port 3306 --user=<UNIQNAME> --enable-cleartext-plugin
#   a) This is a local version of our DB that is connected to the proxy, which forwards changes to the REAL DB

# Prerequisites:
# 1) You have downloaded the gcloud CLI by following this tutorial -> https://cloud.google.com/sdk/docs/install
# 2) You have downloaded cloud-sql-proxy -> brew install cloud-sql-proxy
# 3) You have downloaded mysql -> brew install mysql
# If these are not met, the script will fail and alert you on which you are missing.

INSTANCE="thebuilders:us-central1:db"
HOST="127.0.0.1"
PORT="3306"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <UNIQNAME>"
  exit 1
fi
UNIQ="$1"

missing=()

have() { command -v "$1" >/dev/null 2>&1; }

have gcloud || missing+=("gcloud (Google Cloud SDK)")
have cloud-sql-proxy || missing+=("cloud-sql-proxy (Cloud SQL Auth Proxy v2)")
have mysql || missing+=("mysql (MySQL client)")

if (( ${#missing[@]} > 0 )); then
  echo "❌ Missing required tools:"
  for m in "${missing[@]}"; do echo "  - $m"; done
  exit 1
fi

echo "-> Setting Application Default Credentials..."
gcloud auth application-default login

echo "-> Starting Cloud SQL Auth Proxy for $INSTANCE ..."
# Stop proxy when the script exits
cleanup() {
  if [[ -n "${PROXY_PID:-}" ]] && ps -p "$PROXY_PID" >/dev/null 2>&1; then
    kill "$PROXY_PID" || true
    wait "$PROXY_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

cloud-sql-proxy --auto-iam-authn "$INSTANCE" >/tmp/cloud-sql-proxy.log 2>&1 &
PROXY_PID=$!
echo "   proxy pid: $PROXY_PID (logs: /tmp/cloud-sql-proxy.log)"

# Briefly wait for the port to accept connections
for _ in {1..20}; do
  (echo > /dev/tcp/$HOST/$PORT) >/dev/null 2>&1 && break || true
  sleep 0.2
done

echo "-> Launching mysql as user '${UNIQ}' ..."
echo "   If you are using IAM DB Auth and get 1045, rerun with '-p' and press Enter at the prompt."
mysql --host "$HOST" --port "$PORT" \
  --user="$UNIQ" \
  --enable-cleartext-plugin
