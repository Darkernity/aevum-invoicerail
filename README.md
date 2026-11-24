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

## Testnet deployment (deployed 2026-11-24)

| Item | Value |
|---|---|
| InvoiceCheckout on Aevum testnet (44005) | [`0x35492621EFA400792010757D443dE65dB80A79a0`](https://explorer-test.qday.info/address/0x35492621EFA400792010757D443dE65dB80A79a0) (deploy tx `0x773bbdc6818c2e1c83b82abb96537b815a88a09987baeffa0b85b74f3825788c`) |
| Deployed commit | `57c94261f9ca94a2798f33cc66b5ef1913835875` |
| createInvoice tx | [`0x3a8eb23a000de95484c4f7286cc7d9a3c0fba7936126ffff73dfd912f68bfd00`](https://explorer-test.qday.info/tx/0x3a8eb23a000de95484c4f7286cc7d9a3c0fba7936126ffff73dfd912f68bfd00) (invoice `keccak("aevum-invoice-001")`, 1.05 tUSD8) |
| pay tx | [`0x2a68b10e207743a84000163ecfe4c9d96deb106003ed8e78bc6e6318cc13db20`](https://explorer-test.qday.info/tx/0x2a68b10e207743a84000163ecfe4c9d96deb106003ed8e78bc6e6318cc13db20) (exact amount; `isPaid`/`paymentOf` verified on chain) |
| payWithAuthorization (gasless) tx | [`0x45ee12af8dd04574664a77c91ff2714f4f527368a4f6971280dab8f7cfe15380`](https://explorer-test.qday.info/tx/0x45ee12af8dd04574664a77c91ff2714f4f527368a4f6971280dab8f7cfe15380) (invoice `keccak("aevum-invoice-002")`, 2.00 tUSD8; createInvoice tx `0x5121904f9da4e217ca2776ed88f9e51de6b4de5ff3874d9b464942ed95c29ddb`) |
| Test wallet (faucet / deployer) | `0x502D17a8cd1b9024Eab9A036F1EFcD2d48d51b64` (also merchant and payer — single test wallet by design, so payments are self-transfers and the `Paid` records are the receipts) |

### Supplementary evidence — independent roles (2026-11-24)

The first evidence set above intentionally used one wallet. A second set on the **same deployed contract** uses three distinct wallets — merchant `0x502D…b64`, payer `0x638AEdE47aDdb6d6DE27bAAD23E939F48c6F1f6C`, relayer `0xEAb839A18Bf22008A11177901C14D01A3d83e985`:

| Evidence | Tx | What it proves |
|---|---|---|
| Invoice #3 pay, 1.25 tUSD8 | [`0x70c256b9…922e`](https://explorer-test.qday.info/tx/0x70c256b93d567d502814068acfdca909c7cd65a0c98869d12c05c8c63826922e) | Independent buyer paid an independent merchant; merchant balance rose exactly +1.25 tUSD8 (2.00 → 3.25) |
| Invoice #4 gasless, 1.50 tUSD8 | [`0x19682212…e95b`](https://explorer-test.qday.info/tx/0x196822124b0628354c130c8b6ad158083306d6fbd6b600604b1efdac7491e95b) | True relay: `tx.from` is the relayer (paid the gas), the EIP-3009 signer and recorded payer is the buyer; merchant +1.50 tUSD8 exactly |
| Invoice #5 wrong-amount pay (0.74 vs 0.75) | [`0xa134579c…ed84a`](https://explorer-test.qday.info/tx/0xa134579c6192d679677249e170975285f796cf689f23d414505ed4664e3ed84a) | On testnet, not just on a fork: receipt status 0 (reverted `WrongAmount`), invoice stays unpaid |

## Design notes & known limitations

- **Who can pay:** invoices are payable by any payer; the receipt records the actual payer. An invoice does not name an expected buyer — this is deliberate (open / third-party payment), not an oversight.
- **Token assumption:** amounts are enforced at face value, so the token must be a standard ERC-20 with no transfer fee. tUSD8 qualifies (the fork test asserts the merchant balance rises by exactly the invoice amount). A fee-on-transfer token would settle less than the recorded amount.
- **EIP-3009 compatibility** is verified two ways: fork tests against the real tUSD8 contract, and live testnet transactions (invoices #2 and #4 above). The authorization nonce is bound to this contract and the order id (`keccak256(contract, orderId)`), so a signature cannot be replayed against another invoice or another deployment.
- **Zero-address `from`:** `payWithAuthorization` does not special-case `from == address(0)`; it is unreachable with the real tUSD8, whose EIP-3009 signature recovery can never yield the zero address, so no payment can be recorded without funds moving.
- **Invoice lifecycle:** there is no cancel / refund / amend / expiry in this version. A wrongly-registered invoice is abandoned and re-issued under a new order id; tokens sent to the contract outside the payment functions cannot be recovered. This is a known boundary, on the roadmap for a v2 (merchant-signed cancellations and refund-to-payer).
- **Tests:** regression tests for cross-path double payment, invalid signature, expired authorization, gasless payment recording and failed-transfer rollback were added after deployment (2026-11-24). The contract source is byte-identical to the deployed commit `57c9426`; only tests and docs changed afterwards.

## Live demo

The demo runs against the deployed testnet contract above (not a fork) — see [DEMO.md](DEMO.md) for the exact configuration, cold-start steps and rehearsal record. The full testnet evidence log (all transactions, balances and verification reads) is in [TESTNET-EVIDENCE.md](TESTNET-EVIDENCE.md).

## Network

QDay Aevum Testnet · chain `44005` · RPC `https://rpc-test.qday.info` · explorer `https://explorer-test.qday.info` · tUSD8 `0x456569838f1d43009A91ebA4263147Afd7233483` (6 decimals) · Shanghai EVM (no Cancun opcodes; `make build` checks this) · legacy transactions.

## License & credits

MIT — see [LICENSE](LICENSE). Based on the **Aevum Starter Kit** (MIT, PQA Labs); the original `Checkout`, web scaffolding, `@aevum-kit/aevum` package and examples come from that kit. Third-party licenses are listed in [NOTICE.md](NOTICE.md). InvoiceRail adds the invoice registry, exact-amount enforcement, its tests, and the invoice web flow on top.
