# FIXIS PRO v1.5.0 — Wallet v2 + Settlements

## Added
- Wallet V2 based on `financial_ledger_entries` and `get_wallet_summary()`.
- Available, reserved, total earned and total withdrawn metrics.
- Withdrawal requests through `request_withdrawal()` RPC.
- Partial withdrawals.
- Withdrawal history with requested / processing / paid / rejected / cancelled states.
- Cancellation through `cancel_withdrawal()` while status is `requested`.
- Bank destination shown from the professional profile.
- Recent earnings read from the financial ledger.

## Removed from client flow
- No direct reads/writes to `wallet_transactions` for wallet accounting.
- No direct INSERT for withdrawals.
- No fake "processed successfully / next Friday" confirmation.

## Security
- Monetary mutations remain backend RPC controlled.
- Flutter reads only rows allowed by RLS.
