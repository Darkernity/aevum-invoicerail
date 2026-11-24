# InvoiceRail — Live Demo Runbook

**Decision (review F-16): the live demo runs against the deployed Aevum testnet
contract (chain 44005), not a local fork.** What judges see on screen is the same
contract and the same chain as the submitted testnet evidence. A fork is kept only
as a disclosed fallback (see "If the testnet RPC is down" below).

## Configuration

Deployed contract: `0x35492621EFA400792010757D443dE65dB80A79a0` (deploy block 3939982, chain 44005; set `NEXT_PUBLIC_DEPLOY_BLOCK_AEVUM=3939982` to speed up the Activity page).

`web/.env.local` for the demo machine:

```
NEXT_PUBLIC_NETWORKS=aevum
NEXT_PUBLIC_CHECKOUT_AEVUM=0x35492621EFA400792010757D443dE65dB80A79a0
NEXT_PUBLIC_REPO_URL=https://github.com/Darkernity/aevum-invoicerail
```

Demo wallets (testnet only, faucet-funded): merchant/deployer wallet holds tQDAY
for `createInvoice`; a separate buyer wallet holds tUSD8 + a little tQDAY for
`approve + pay`. The gasless path can be shown with the web relayer configured
(`RELAYER_PRIVATE_KEY` = a test wallet) or replayed from evidence invoice #4.

## Cold-start script (screen flow)

1. `pnpm --filter web dev` (or the production build) → open http://localhost:3000 — header shows **Aevum testnet 44005** and the deployed checkout address.
2. As merchant: create an invoice (order id + amount) → `InvoiceCreated` on chain; show the tx on https://explorer-test.qday.info.
3. As buyer: pay the exact amount → `Paid` event; open the receipts page for the order id — it cross-checks `paymentOf` against `invoiceOf` and shows the verified receipt.
4. Show the wrong-amount guard live: attempt to pay 0.01 less → the transaction reverts with `WrongAmount` (same behaviour as evidence invoice #5, tx `0xa134579c…ed84a`).
5. Show the gasless evidence: invoice #4 tx `0x19682212…e95b` — point at `tx.from` (relayer) vs the recorded payer (buyer) in `paymentOf`.

## Rehearsal record (2026-11-24)

- Every contract call in steps 2–5 was executed against the deployed testnet
  contract from the CLI on 2026-11-24 with the exact demo addresses and amounts
  (createInvoice ×3, approve, pay, relayed payWithAuthorization, wrong-amount
  revert) — see the supplementary evidence in the project evidence log; all
  receipts verified on chain.
- Web app: `pnpm -r typecheck` green; the app defaults to the `aevum` network and
  takes the checkout address from `NEXT_PUBLIC_CHECKOUT_AEVUM` (see
  `web/src/lib/env.ts`), so no code change is needed to point it at the deployed
  contract.
- Not rehearsed headlessly: the browser wallet-extension click path itself
  (injected wallet signing). It is the kit's stock flow, exercised during
  development on the local fork; allow ~2 minutes of slack in the live slot for
  wallet popups.

## If the testnet RPC is down at demo time

Fallback, disclosed on screen at the start: `make fork` (local copy of testnet,
chain 440050) with the same flow, opening with the words "this is a local fork
reproduction; the testnet evidence is in the submission links" — fork receipts are
never presented as testnet receipts.
