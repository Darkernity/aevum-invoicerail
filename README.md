# InvoiceRail — Invoice Payments on Aevum

InvoiceRail is a minimal invoice-payment app for **QDay Aevum testnet** (chain `44005`), built for the **Aevum Builder Challenge #1 — Invoice Payments** track.

## The problem

The starter `Checkout` contract records any payment for any amount: `pay(orderId, 1)` can mark an order as paid for 0.000001 tUSD8 and front-run the real payer. For invoices that is fatal — "paid" alone proves nothing about *how much* was owed or paid.

## What InvoiceRail does

The merchant registers the invoice on chain first. Only then can it be paid, and only for **exactly** the registered amount:

- `InvoiceCheckout.createInvoice(orderId, amount)` — merchant-only, amount > 0, no duplicate registration.
- `pay(orderId, amount)` and `payWithAuthorization(...)` (EIP-3009, gasless) both revert with `UnknownInvoice` for unregistered ids and `WrongAmount` unless `amount` equals the registered amount exactly.
- The original `Paid(orderId, payer, amount)` event is unchanged and serves as the receipt; `paymentOf(orderId)` verifies it on chain, and the receipts page cross-checks it against the on-chain `invoiceOf(orderId)`.

## Architecture

```
contracts/src/InvoiceCheckout.sol   invoice registry + exact-amount checkout (Shanghai EVM, legacy-tx friendly)
contracts/src/Checkout.sol          original starter checkout (unchanged, kept for comparison)
contracts/test/InvoiceCheckout.t.sol  unit tests: registration, access control, exact/wrong/unknown, replay, gasless
contracts/test/fork/InvoiceFork.t.sol fork test against the real tUSD8
packages/aevum/                     chain config + ABIs (incl. invoiceCheckoutAbi)
web/                                Next.js app: create invoice → pay (standard / gasless) → receipt
examples/                           starter-kit TypeScript examples (unchanged)
```

## Invoice flow

```
merchant ── createInvoice(orderId, amount) ──▶ InvoiceCheckout   (InvoiceCreated event)
buyer    ── approve(InvoiceCheckout, amount) ─▶ tUSD8
buyer    ── pay(orderId, amount) ────────────▶ InvoiceCheckout ── transferFrom ──▶ merchant   (Paid event = receipt)
   or, gasless:
buyer    ── signs EIP-3009 ReceiveWithAuthorization (nonce = authorizationNonce(orderId)) ── off-chain
relayer  ── payWithAuthorization(orderId, from, amount, …, v, r, s) ──▶ InvoiceCheckout ──▶ merchant
anyone   ── paymentOf(orderId) + invoiceOf(orderId) ──▶ verify receipt amount == registered amount
```

Wrong amount, unregistered invoice, duplicate registration, non-merchant registration, and second payment all revert on chain — they cannot be bypassed from the frontend.

## Run it locally (no funds needed)

```bash
make install   # Solidity libs + JS packages (Node 22+, pnpm, Foundry)
make check     # forge build + Shanghai check + unit tests + fork tests + typecheck

# Local fork end-to-end (terminal 1 / terminal 2):
make fork
export MERCHANT=<merchant address>   # must be exported; `make … MERCHANT=` does not work
# deploy InvoiceCheckout with contracts/script/DeployInvoice.s.sol (see Makefile deploy-fork pattern), then:
make deal TO=<buyer address>
# cast: createInvoice → approve → pay; verify with paymentOf / isPaid
```

Local fork evidence from development (chain `440050`, local only — not testnet activity) is recorded in the project notes; testnet evidence goes in the section below after deployment.

## Testnet deployment (TODO — fill after real deployment)

| Item | Value |
|---|---|
| InvoiceCheckout on Aevum testnet (44005) | _TODO: address + explorer link_ |
| Deployed commit | _TODO_ |
| createInvoice tx | _TODO: hash_ |
| pay tx | _TODO: hash_ |
| payWithAuthorization (gasless) tx | _TODO: hash_ |
| Test wallet (faucet / deployer) | `0x502D17a8cd1b9024Eab9A036F1EFcD2d48d51b64` |

## Network

QDay Aevum Testnet · chain `44005` · RPC `https://rpc-test.qday.info` · explorer `https://explorer-test.qday.info` · tUSD8 `0x456569838f1d43009A91ebA4263147Afd7233483` (6 decimals) · Shanghai EVM (no Cancun opcodes; `make build` checks this) · legacy transactions.

## License & credits

MIT — see [LICENSE](LICENSE). Based on the **Aevum Starter Kit** (MIT, PQA Labs); the original `Checkout`, web scaffolding, `@aevum-kit/aevum` package and examples come from that kit. Third-party licenses are listed in [NOTICE.md](NOTICE.md). InvoiceRail adds the invoice registry, exact-amount enforcement, its tests, and the invoice web flow on top.
