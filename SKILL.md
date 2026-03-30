---
name: xeno-axon
description: Use this skill when an agent or owner needs to top up Xenodia credits with AXON, especially when an agent is paying AXON into its own Xenodia account.
---

# Xeno AXON

## What Xenodia Is

Xenodia is a unified LLM API platform.

At a high level:
- Xenodia provides one account and one API surface for multiple frontier model families
- that includes current ChatGPT / OpenAI models, Claude models, Gemini models, and other supported models configured on the platform
- AXON top-up converts AXON value into Xenodia credit
- that credit is then used for model usage through Xenodia

Public website:
- `https://xenodia.xyz`

Useful public endpoints:
- `GET https://xenodia.xyz/v1/models`
  Returns the current list of available Xenodia models
- `GET https://xenodia.xyz/v1/credits/balance`
  Returns the current credit / funding view for the authenticated account
- `POST https://xenodia.xyz/v1/payments/axon/quote`
  Returns the current AXON receiving address and quote inputs

If the user or agent does not know Xenodia yet, explain it as:
- a single API gateway for multiple major models
- a place where AXON can be exchanged into usable inference credit
- a system where an agent can log in with its wallet, top up with AXON, and then spend that credit on model calls

Use this skill when the task is about:
- agent self top-up with AXON
- owner AXON top-up
- agent wallet login
- owner wallet binding
- AXON order flow
- AXON `redeem-hash` flow

All public API calls in this skill use:
- `https://xenodia.xyz/v1/...`

Do not use server IPs or private service addresses.

## Priority

Prefer the `agent` self-top-up flow unless the task is explicitly about an owner account.

When explaining the flow to a new user, lead with:
1. Xenodia is the model API platform
2. AXON is only the payment / top-up rail
3. after top-up, the account can use Xenodia credit against the models listed by `/v1/models`

For linked agents:
- AXON top-up credits the **agent account itself**
- it does not credit the owner account
- it does not auto-change `billing_mode`

If a linked agent uses `owner_only` billing mode:
- AXON top-up still lands in the agent's own credit account
- `/v1/credits/balance` may show the funding view in top-level fields
- the response also includes `self_account`, which shows the agent's own stored balance

## Rules

- The AXON transfer must come from the **current authenticated account wallet**.
- The AXON transfer must go to the **current `pay_to_address` returned by the AXON quote API**.
- Do not hardcode the receiving address.
- If AXON returns `202`, do not send another transfer.
- Re-use the same order or the same `tx_hash` until the transaction is confirmed.

## Keyring Wallet Guidance

Axon users often hold funds in a keyring-based wallet instead of a plain exported private key.

If the user has a keyring wallet, there are two valid ways to use Xenodia AXON top-up:

### Option 1: Use the same wallet directly

- If the wallet tooling can expose or derive a standard EVM private key, the agent can use that same wallet for:
  - Xenodia wallet authentication
  - AXON payment
- This keeps one identity:
  - the authenticated Xenodia account wallet
  - the AXON sender wallet
  - the credited Xenodia account

### Option 2: Create a fresh transit payment wallet

- Create a new EVM wallet only for Xenodia top-up.
- Move only the required AXON top-up amount plus gas into that new wallet.
- Use this new wallet for:
  - `POST /v1/auth/challenge`
  - `POST /v1/auth/verify`
  - the AXON payment itself
- This protects the original keyring wallet because the original wallet never has to authenticate to Xenodia directly.

Important consequences of the transit-wallet pattern:

- Xenodia treats the new wallet as the account identity.
- The AXON transfer must be sent from that same new wallet.
- The resulting credit lands on the Xenodia account authenticated by that new wallet.
- It does **not** automatically credit a different existing wallet-backed account.

If the user wants to protect a keyring wallet while still topping up with AXON, the safest default is:
- create a dedicated transit wallet
- fund it only with the exact top-up amount plus gas
- authenticate Xenodia with that transit wallet
- send AXON from that same transit wallet

## Authentication Response Shapes

Do not guess the auth response fields. Use these shapes.

### `POST /v1/auth/challenge`

Request:

```json
{
  "wallet_address": "0xYourWallet"
}
```

Success response:

```json
{
  "challenge_id": "xenodia:1743333333333:abcd1234",
  "message": "Welcome to Xenodia!\n\nSign this message to authenticate your wallet.\n\nWallet: 0xYourWallet\nNonce: <hex>\nTimestamp: 1743333333333",
  "wallet_address": "0xYourWallet",
  "expires_at": 1743333453
}
```

Notes:
- `challenge_id` is required by `POST /v1/auth/verify`
- `message` is the exact EIP-191 message that must be signed
- `expires_at` is a Unix timestamp in seconds

### `POST /v1/auth/verify`

Request:

```json
{
  "challenge_id": "xenodia:1743333333333:abcd1234",
  "signature": "0x..."
}
```

Success response:

```json
{
  "account": {
    "id": 123,
    "account_type": "agent",
    "wallet_address": "0xYourWallet",
    "role": "user"
  },
  "tokens": {
    "access_token": "<jwt>",
    "refresh_token": "<jwt>",
    "api_key": "",
    "expires_in": 3600,
    "token_type": "Bearer"
  }
}
```

Notes:
- For wallet login, the created or reused account is normally an `agent`
- `Authorization` headers should use:
  - `Authorization: Bearer <access_token>`
- `api_key` is present in the response shape but may be an empty string

### `GET /v1/me`

Success response:

```json
{
  "account": {
    "id": 123,
    "account_type": "agent",
    "role": "user",
    "wallet_address": "0xYourWallet"
  },
  "request_id": "req_..."
}
```

For AXON top-up, proceed only if:
- `account.account_type` is the account type you intend to top up
- `account.wallet_address` is the wallet that will actually send AXON

## Recommended Agent Flow

### 1. Log in as agent by wallet

Create a challenge:

```http
POST https://xenodia.xyz/v1/auth/challenge
Content-Type: application/json

{ "wallet_address": "0xAgentWallet" }
```

Sign the returned `message`, then verify:

```http
POST https://xenodia.xyz/v1/auth/verify
Content-Type: application/json

{
  "challenge_id": "xenodia:...",
  "signature": "0x..."
}
```

Successful `verify` returns:

```json
{
  "account": {
    "id": 123,
    "account_type": "agent",
    "wallet_address": "0xAgentWallet",
    "role": "user"
  },
  "tokens": {
    "access_token": "<jwt>",
    "refresh_token": "<jwt>",
    "api_key": "",
    "expires_in": 3600,
    "token_type": "Bearer"
  }
}
```

### 2. Verify the current account context

```http
GET https://xenodia.xyz/v1/me
Authorization: Bearer <agent_token>
```

Proceed only if:
- `account.account_type == "agent"`
- `account.wallet_address` exists
- that wallet is the wallet that will send AXON

### 3. Fetch the current AXON quote

```http
POST https://xenodia.xyz/v1/payments/axon/quote
Authorization: Bearer <agent_token>
Content-Type: application/json

{ "credit_usd": "10" }
```

Important fields:
- `pay_to_address`
- `payer_wallet_address`
- `expected_axon_wei`
- `usd_per_axon_rate`

### 4. Choose one of two paths

Path A:
- `quote -> order -> pay -> get/reconcile`

Path B:
- `quote -> pay -> redeem-hash`

## Order Flow

Create an order:

```http
POST https://xenodia.xyz/v1/payments/axon/order
Authorization: Bearer <token>
Content-Type: application/json

{ "credit_usd": "10" }
```

Send AXON from the current account wallet to `pay_to_address`.

Then either:

```http
GET https://xenodia.xyz/v1/payments/axon/orders/123
Authorization: Bearer <token>
```

or:

```http
POST https://xenodia.xyz/v1/payments/axon/reconcile
Authorization: Bearer <token>
Content-Type: application/json

{
  "order_id": 123,
  "tx_hash": "0x..."
}
```

The order only completes if:
- `from == current account wallet`
- `to == current pay_to_address`
- `value == expected_axon_wei`
- `receipt.status == 1`

## Manual Redeem by Tx Hash

If the AXON transfer is already sent:

```http
POST https://xenodia.xyz/v1/payments/axon/redeem-hash
Authorization: Bearer <token>
Content-Type: application/json

{
  "tx_hash": "0x..."
}
```

Expected responses:
- `200`: `status=completed`
- `202`: `status=pending|confirming`
- `400`: invalid amount, invalid hash, wrong payer, wrong pay-to, or tx not found
- `403`: unsupported account context
- `409`: tx already claimed or closed
- `429`: rate limited

## Owner Wallet Binding

Use this only when the task is explicitly about owner AXON top-up.

### Owner already has login

```http
POST https://xenodia.xyz/v1/auth/challenge
Content-Type: application/json

{ "wallet_address": "0xOwnerWallet" }
```

Sign the returned message, then bind:

```http
PUT https://xenodia.xyz/v1/me/wallet
Authorization: Bearer <owner_token>
Content-Type: application/json

{
  "challenge_id": "xenodia:...",
  "signature": "0x..."
}
```

### Linked agent binds owner wallet with delegation

1. Owner creates a delegation token:

```http
POST https://xenodia.xyz/v1/me/wallet/delegation
Authorization: Bearer <owner_token>
Content-Type: application/json

{ "agent_wallet_address": "0xLinkedAgentWallet" }
```

2. Agent creates a challenge for the target owner wallet.
3. The owner wallet signs the challenge.
4. Agent submits:

```http
POST https://xenodia.xyz/v1/me/owner-wallet/bind
Authorization: Bearer <agent_token>
Content-Type: application/json

{
  "delegation_token": "string",
  "challenge_id": "xenodia:...",
  "signature": "0x..."
}
```

Delegation does not replace real wallet signing.

## Practical Notes

- Use quote every time before sending AXON.
- Never hardcode `pay_to_address`.
- For linked agents, AXON top-up is still self top-up.
- For `owner_only` linked agents, check `self_account` in `/v1/credits/balance` if you need the agent's own stored AXON top-up balance.

## After Top-Up

After authentication and AXON top-up succeed, if the agent wants to switch to Xenodia as its LLM provider, refer to:

- `https://www.xenodia.xyz/skill`

That page explains how to start using Xenodia after the account already has credit.
