#!/usr/bin/env bash
# Ships the current checkout to the family server and restarts it.
#
#   scripts/deploy.sh family@203.0.113.10 [remote-dir]
#
# What it does NOT send: .env, secrets/, or anything else gitignored. Those
# live on the server and are set up once by hand (docs/hosting.md). A deploy
# that could overwrite the server's secrets from a laptop is a deploy that
# eventually does.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
host="${1:-}"
dir="${2:-family}"
if [[ -z "$host" ]]; then
  echo "Usage: $0 <user@host> [remote-dir]" >&2
  exit 2
fi

# Only what the server builds from: the backend source and the compose files.
# The Flutter app, the docs and the Rust core have no business on it.
echo "Sending backend/ and infra/ to $host:$dir"
rsync -az --delete \
  --exclude 'bin/' --exclude 'obj/' \
  --exclude '.env' --exclude 'secrets/' \
  "$here/backend/" "$host:$dir/backend/"
rsync -az \
  --exclude '.env' --exclude 'secrets/' \
  "$here/infra/" "$host:$dir/infra/"

echo "Building and restarting"
# --build because the API image is built from the source just sent. Postgres
# and Caddy keep their volumes: this is a restart, not a reinstall.
ssh "$host" "cd '$dir/infra' && docker compose up -d --build"

echo "Waiting for health"
domain="$(ssh "$host" "sed -n 's/^DOMAIN=//p' '$dir/infra/.env'" | tr -d '\r')"
if [[ -z "$domain" ]]; then
  echo "No DOMAIN in the server's .env; skipping the check." >&2
  exit 0
fi

for _ in $(seq 1 30); do
  if curl -fsS --max-time 5 "https://$domain/v1/health" >/dev/null 2>&1; then
    echo
    echo "https://$domain is up."
    curl -fsS "https://$domain/v1/health"
    echo
    exit 0
  fi
  sleep 2
done

echo >&2
echo "It did not answer on https://$domain within a minute:" >&2
ssh "$host" "cd '$dir/infra' && docker compose ps && docker compose logs --tail 40 api caddy" >&2
exit 1
