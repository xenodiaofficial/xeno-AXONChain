# Xeno AXON

`xeno-axon` explains how to top up Xenodia credit with AXON.

The primary use case is:
- an `agent` holds AXON and tops up its own Xenodia account
- the agent may be a standalone agent or a linked agent

## What Xenodia Is

Xenodia is a unified LLM API platform.

In practice:
- you integrate with one Xenodia API
- but you can access multiple major model families through it
- including current ChatGPT / OpenAI models, Claude models, Gemini models, and other models Xenodia has configured

AXON is not used to buy one specific model directly. Instead:
- AXON is converted into Xenodia credit
- that credit is then spent on model usage through Xenodia

Public website:
- `https://xenodia.xyz`

Important public endpoints for new users:
- `GET https://xenodia.xyz/v1/models`
  Returns the current list of available models
- `GET https://xenodia.xyz/v1/credits/balance`
  Returns the current credit / funding view for the account
- `POST https://xenodia.xyz/v1/payments/axon/quote`
  Returns the current AXON receiving address and quote data

All public API calls use:
- `https://xenodia.xyz/v1/...`

Do not use server IPs or private service addresses.

## Keyring Wallet Users

If the user holds AXON in a keyring-based wallet, there are two practical ways to use Xenodia:

1. Use the same wallet directly
   - If the wallet setup can expose a standard EVM private key, use that wallet both for Xenodia login and for the AXON payment.
2. Use a fresh transit wallet
   - Create a new EVM wallet only for Xenodia.
   - Move only the exact AXON top-up amount plus gas into it.
   - Authenticate Xenodia with that new wallet and send AXON from that same new wallet.

Important:
- Xenodia ties AXON authentication and AXON payment to the same wallet identity.
- If you use a transit wallet, the resulting credit lands on the Xenodia account for that transit wallet.
- It does not automatically top up a different existing wallet-backed account.

## Core Rules

- AXON top-up is available to `owner` and `agent` accounts, as long as the current account has a valid wallet context.
- For an `agent`, the payer wallet is the current logged-in agent wallet.
- For an `owner`, the payer wallet is the current bound owner wallet.
- AXON must be sent to the **current** `pay_to_address` returned by the quote API.
- Do not hardcode the receiving address.
- A `tx_hash` can only be claimed once.
- If the API returns `202`, the transaction is still confirming. Do not send a second transfer.

## Recommended First: Agent Self Top-Up

### Case 1: Standalone agent

1. Log in with the agent wallet:
   - `POST /v1/auth/challenge`
   - sign the challenge message
   - `POST /v1/auth/verify`
2. After receiving the agent token, call:
   - `GET /v1/me`
   - confirm the current account is an `agent`
   - confirm `wallet_address` is the wallet that will send AXON
3. Call:
   - `POST /v1/payments/axon/quote`
4. Read these fields from the quote response:
   - `pay_to_address`
   - `payer_wallet_address`
   - `usd_per_axon_rate`
   - `expected_axon_wei`
5. Send AXON on Axon mainnet from the current agent wallet
6. Use one of the two top-up paths:
   - recommended: `order -> pay -> get/reconcile`
   - manual: `quote -> pay -> redeem-hash`

### Case 2: Linked agent

A linked agent AXON top-up still credits the **agent account itself**, not the owner account.

That remains true even if the linked agent billing policy is:
- `self_only`
- `self_then_owner`
- `owner_only`

AXON top-up will still:
- credit the agent's own credit account
- leave the billing policy unchanged

If the billing policy is `owner_only`:
- `/v1/credits/balance` still shows the current funding view in its top-level balance fields
- the response also includes `self_account`
- the AXON credit stored on the agent account is visible in `self_account`

## Two Top-Up Methods

## Method A: Order flow

Use this when you want the quoted AXON amount and credited USD amount frozen into an order.

### Flow

1. `POST /v1/payments/axon/quote`
2. `POST /v1/payments/axon/order`
3. Send the **exact** AXON amount from the current account wallet
4. Poll:
   - `GET /v1/payments/axon/orders/:id`
5. Or reconcile manually:
   - `POST /v1/payments/axon/reconcile`

### Order flow requirements

- `from == current account wallet`
- `to == current quote/order pay_to_address`
- `value == expected_axon_wei`
- `receipt.status == 1`

## Method B: Manual transfer + tx hash redeem

Use this when the transfer is sent manually and the credit is claimed later by transaction hash.

### Flow

1. `POST /v1/payments/axon/quote`
2. Send AXON from the current account wallet to `pay_to_address`
3. After the transfer succeeds, call:
   - `POST /v1/payments/axon/redeem-hash`

Request body:

```json
{
  "tx_hash": "0x..."
}
```

### Response meanings

- `200`: credited successfully
- `202`: accepted, still confirming
- `400`: invalid request, amount too small, from/to mismatch, or tx not found
- `403`: current account context is not allowed
- `409`: `tx_hash` already claimed or closed
- `429`: rate limited

## Owner Usage

If the top-up is for an owner account:

1. Confirm the owner wallet is already bound
2. If not, do:
   - `POST /v1/auth/challenge`
   - sign the challenge
   - `PUT /v1/me/wallet`
3. Then use the same payment flows as an agent:
   - `quote`
   - `order/reconcile`
   - or `redeem-hash`

## Included Script

Script location:
- [scripts/axon_api.sh](/Users/uniteyoo/Documents/myxenoall/xeno-axon/scripts/axon_api.sh)

This script only helps call Xenodia HTTP APIs. It does not handle:
- wallet signing
- MetaMask / WalletConnect
- on-chain AXON transfers

### Environment variables

```bash
export XENODIA_BASE_URL="https://xenodia.xyz/v1"
export XENODIA_TOKEN="<access_token>"
```

### Examples

Show the current account:

```bash
./scripts/axon_api.sh me
```

Fetch a quote:

```bash
./scripts/axon_api.sh quote --credit-usd 10
./scripts/axon_api.sh quote --pay-axon 25
```

Create an order:

```bash
./scripts/axon_api.sh order --credit-usd 10
```

Fetch an order:

```bash
./scripts/axon_api.sh get-order 123
```

Reconcile an order:

```bash
./scripts/axon_api.sh reconcile 123 0xabc...
```

Redeem a manual transfer by tx hash:

```bash
./scripts/axon_api.sh redeem-hash 0xabc...
```

Agent wallet login:

```bash
./scripts/axon_api.sh challenge 0xAgentWallet
./scripts/axon_api.sh verify xenodia:challenge-id 0xSignature
```

Bind an owner wallet:

```bash
./scripts/axon_api.sh bind-owner-wallet xenodia:challenge-id 0xSignature
```

## Files

- [SKILL.md](/Users/uniteyoo/Documents/myxenoall/xeno-axon/SKILL.md)
  Execution guidance for an agent or Codex, with agent self top-up as the primary path
- [scripts/axon_api.sh](/Users/uniteyoo/Documents/myxenoall/xeno-axon/scripts/axon_api.sh)
  Helper script for calling Xenodia AXON-related APIs
