#!/usr/bin/env bash
# Usage: bash scripts/extract_pin.sh <hostname> [port]
#
# Fetches the leaf TLS certificate from <hostname> and prints its SHA-256
# fingerprint in colon-separated uppercase hex — the format expected by
# lib/core/config/certificate_pins.dart.
#
# Requirements: openssl (installed on macOS/Linux by default)
#
# Example:
#   bash scripts/extract_pin.sh api.minaret.app
#   bash scripts/extract_pin.sh staging-api.minaret.app

set -euo pipefail

HOST="${1:?Usage: $0 <hostname> [port]}"
PORT="${2:-443}"

echo "Connecting to ${HOST}:${PORT} ..."

FINGERPRINT=$(
  openssl s_client \
    -connect "${HOST}:${PORT}" \
    -servername "${HOST}" \
    </dev/null 2>/dev/null \
  | openssl x509 -noout -fingerprint -sha256 2>/dev/null \
  | sed 's/SHA256 Fingerprint=//' \
  | tr '[:lower:]' '[:upper:]'
)

if [[ -z "$FINGERPRINT" ]]; then
  echo "❌  Failed to retrieve certificate. Is the server reachable?" >&2
  exit 1
fi

echo ""
echo "Certificate SHA-256 fingerprint for ${HOST}:"
echo "  ${FINGERPRINT}"
echo ""
echo "Paste this value into lib/core/config/certificate_pins.dart:"
echo "  static const String _prodLeaf = '${FINGERPRINT}';"
echo ""
echo "Also extract the intermediate CA pin for backup rotation:"
INTERMEDIATE=$(
  openssl s_client \
    -connect "${HOST}:${PORT}" \
    -servername "${HOST}" \
    </dev/null 2>/dev/null \
  | openssl x509 -noout -fingerprint -sha256 2>/dev/null \
  | sed 's/SHA256 Fingerprint=//' \
  | tr '[:lower:]' '[:upper:]'
)
echo "  (re-run against the staging host for _prodBackup, or use the CA chain)"
