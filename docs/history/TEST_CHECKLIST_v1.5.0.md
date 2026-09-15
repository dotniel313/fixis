# FIXIS PRO v1.5.0 — Test Checklist

## Preconditions
- Migration 010 applied.
- Migration 011 applied.
- Professional has bank/account data.
- Current expected wallet before test:
  - available: 45.50
  - reserved: 0.00
  - earned: 45.50
  - withdrawn: 0.00

## Wallet UI
- [ ] Wallet opens without querying legacy `wallet_transactions`.
- [ ] Available = 45.50.
- [ ] Reserved = 0.00.
- [ ] Earned = 45.50.
- [ ] Withdrawn = 0.00.
- [ ] Bank account is masked.
- [ ] Recent earning +45.50 is visible.

## Request test: USD 20
- [ ] Request 20.00 from Flutter.
- [ ] settlement created with status `requested`.
- [ ] settlement_items allocation totals 20.00.
- [ ] Wallet refreshes to available 25.50.
- [ ] Reserved becomes 20.00.
- [ ] Earned remains 45.50.
- [ ] Withdrawn remains 0.00.

## Cancel test (optional before processing)
- [ ] Cancel requested settlement.
- [ ] status becomes `cancelled`.
- [ ] available returns to 45.50.
- [ ] reserved returns to 0.00.

## Processing / Paid test
- [ ] Trusted function sets settlement to processing.
- [ ] Paid function sets settlement to paid.
- [ ] Exactly one `settlement_debit` is created.
- [ ] Debit references `settlement_id`.
- [ ] Wallet = available 25.50, reserved 0.00, withdrawn 20.00.
- [ ] Calling paid function again does not create a second debit.
