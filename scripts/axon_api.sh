#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${XENODIA_BASE_URL:-https://xenodia.xyz/v1}"
TOKEN="${XENODIA_TOKEN:-}"

usage() {
  cat <<'EOF'
Usage:
  axon_api.sh me
  axon_api.sh quote --credit-usd <amount>
  axon_api.sh quote --pay-axon <amount>
  axon_api.sh order --credit-usd <amount>
  axon_api.sh order --pay-axon <amount>
  axon_api.sh get-order <order_id>
  axon_api.sh reconcile <order_id> <tx_hash>
  axon_api.sh redeem-hash <tx_hash>
  axon_api.sh challenge <wallet_address>
  axon_api.sh verify <challenge_id> <signature>
  axon_api.sh bind-owner-wallet <challenge_id> <signature>
  axon_api.sh create-delegation <agent_wallet_address>
  axon_api.sh bind-owner-by-agent <delegation_token> <challenge_id> <signature>

Environment:
  XENODIA_BASE_URL   Optional. Defaults to https://xenodia.xyz/v1
  XENODIA_TOKEN      Required for authenticated commands

Notes:
  - This script only calls Xenodia HTTP APIs.
  - It does not sign wallet messages.
  - It does not send on-chain AXON transfers.
EOF
}

require_token() {
  if [[ -z "${TOKEN}" ]]; then
    echo "XENODIA_TOKEN is required for this command" >&2
    exit 1
  fi
}

post_json() {
  local url="$1"
  local body="$2"
  shift 2
  curl -sS \
    -H "Content-Type: application/json" \
    "$@" \
    --data "$body" \
    "$url"
  echo
}

auth_header() {
  printf 'Authorization: Bearer %s' "${TOKEN}"
}

command="${1:-}"
if [[ -z "${command}" ]]; then
  usage
  exit 1
fi
shift || true

case "${command}" in
  me)
    require_token
    curl -sS "${BASE_URL}/me" -H "$(auth_header)"
    echo
    ;;

  quote|order)
    require_token
    if [[ $# -ne 2 ]]; then
      usage
      exit 1
    fi
    flag="$1"
    value="$2"
    case "${flag}" in
      --credit-usd)
        body=$(printf '{"credit_usd":"%s"}' "${value}")
        ;;
      --pay-axon)
        body=$(printf '{"pay_axon":"%s"}' "${value}")
        ;;
      *)
        usage
        exit 1
        ;;
    esac
    post_json "${BASE_URL}/payments/axon/${command}" "${body}" -H "$(auth_header)"
    ;;

  get-order)
    require_token
    if [[ $# -ne 1 ]]; then
      usage
      exit 1
    fi
    curl -sS "${BASE_URL}/payments/axon/orders/$1" -H "$(auth_header)"
    echo
    ;;

  reconcile)
    require_token
    if [[ $# -ne 2 ]]; then
      usage
      exit 1
    fi
    post_json \
      "${BASE_URL}/payments/axon/reconcile" \
      "$(printf '{"order_id":%s,"tx_hash":"%s"}' "$1" "$2")" \
      -H "$(auth_header)"
    ;;

  redeem-hash)
    require_token
    if [[ $# -ne 1 ]]; then
      usage
      exit 1
    fi
    post_json \
      "${BASE_URL}/payments/axon/redeem-hash" \
      "$(printf '{"tx_hash":"%s"}' "$1")" \
      -H "$(auth_header)"
    ;;

  challenge)
    if [[ $# -ne 1 ]]; then
      usage
      exit 1
    fi
    post_json \
      "${BASE_URL}/auth/challenge" \
      "$(printf '{"wallet_address":"%s"}' "$1")"
    ;;

  verify)
    if [[ $# -ne 2 ]]; then
      usage
      exit 1
    fi
    post_json \
      "${BASE_URL}/auth/verify" \
      "$(printf '{"challenge_id":"%s","signature":"%s"}' "$1" "$2")"
    ;;

  bind-owner-wallet)
    require_token
    if [[ $# -ne 2 ]]; then
      usage
      exit 1
    fi
    post_json \
      "${BASE_URL}/me/wallet" \
      "$(printf '{"challenge_id":"%s","signature":"%s"}' "$1" "$2")" \
      -X PUT \
      -H "$(auth_header)"
    ;;

  create-delegation)
    require_token
    if [[ $# -ne 1 ]]; then
      usage
      exit 1
    fi
    post_json \
      "${BASE_URL}/me/wallet/delegation" \
      "$(printf '{"agent_wallet_address":"%s"}' "$1")" \
      -H "$(auth_header)"
    ;;

  bind-owner-by-agent)
    require_token
    if [[ $# -ne 3 ]]; then
      usage
      exit 1
    fi
    post_json \
      "${BASE_URL}/me/owner-wallet/bind" \
      "$(printf '{"delegation_token":"%s","challenge_id":"%s","signature":"%s"}' "$1" "$2" "$3")" \
      -H "$(auth_header)"
    ;;

  *)
    usage
    exit 1
    ;;
esac
