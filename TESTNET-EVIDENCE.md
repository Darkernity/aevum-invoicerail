# InvoiceRail — Aevum Testnet Deployment & Evidence (2026-11-24)

Chain: QDay Aevum Testnet 44005 · RPC https://rpc-test.qday.info · Explorer https://explorer-test.qday.info
Test wallet (deployer / merchant / payer — single test wallet by design): 0x502D17a8cd1b9024Eab9A036F1EFcD2d48d51b64
Deployed tree commit: 57c94261f9ca94a2798f33cc66b5ef1913835875 (local commit on top of kit e87bcff; not yet pushed)

## Balance check before deploy (matched faucet exactly)

- tQDAY (native): 1.000000000000000000 (faucet tx 0x6d1dcef559297786e7aaed6dda4b49586cc91d27e0506807b5bee8bd961d498b)
- tUSD8: 5000000 raw = 5.000000 (faucet tx 0xf79b0b98bcb30d26cbee9f497c687b4229b9c47b1c275d59bf5a13de02c3c98c)
- tUSD8: 0x456569838f1d43009A91ebA4263147Afd7233483, 6 decimals, DOMAIN_SEPARATOR 0x7838e6c46f8f9874236c9747d9896552a03d22c7c3e701b198879de2cb658022

## Deployment

- InvoiceCheckout: 0x35492621EFA400792010757D443dE65dB80A79a0
  https://explorer-test.qday.info/address/0x35492621EFA400792010757D443dE65dB80A79a0
- Deploy tx: 0x773bbdc6818c2e1c83b82abb96537b815a88a09987baeffa0b85b74f3825788c
  https://explorer-test.qday.info/tx/0x773bbdc6818c2e1c83b82abb96537b815a88a09987baeffa0b85b74f3825788c
- On-chain check: merchant() = test wallet, token() = real tUSD8, code present. Deployed via
  contracts/script/DeployInvoice.s.sol with --legacy, keystore account `aevum-test`
  (imported from test-wallet.txt; keystore password in ~/workspace/aevum-build/keystore-password.txt, 600).
  MERCHANT deliberately = test wallet (single-wallet evidence setup: deployer = merchant = payer,
  so pay transfers are self-transfers and net tUSD8 is unchanged; Paid records are on chain).

## Evidence transactions (all status 0x1)

Invoice #1: orderId 0xbafd217f637ca7faff46f1f9a6ef2e0222654cff13e1565aecfe91986d95b36d = keccak("aevum-invoice-001"), amount 1050000 (1.05 tUSD8, same as local fork e2e)

1. createInvoice #1 tx: 0x3a8eb23a000de95484c4f7286cc7d9a3c0fba7936126ffff73dfd912f68bfd00 (block 3940010)
   https://explorer-test.qday.info/tx/0x3a8eb23a000de95484c4f7286cc7d9a3c0fba7936126ffff73dfd912f68bfd00
   invoiceOf -> (1050000, true)
2. approve tx: 0x2b569835427bac9ddb364c14ac33764a50100985753f37869784564a0303eab1 (block 3940015)
3. pay (exact amount) tx: 0x2a68b10e207743a84000163ecfe4c9d96deb106003ed8e78bc6e6318cc13db20 (block 3940031)
   https://explorer-test.qday.info/tx/0x2a68b10e207743a84000163ecfe4c9d96deb106003ed8e78bc6e6318cc13db20
   isPaid -> true; paymentOf -> (payer 0x502D17a8cd1b9024Eab9A036F1EFcD2d48d51b64, paidAt 1795459448, amount 1050000)

Invoice #2 (gasless): orderId 0xb7ecfdd64e88ab03fc7e5df5d3678f392520497025ba39c6ad3a498caf9ea956 = keccak("aevum-invoice-002"), amount 2000000 (2.00 tUSD8)

4. createInvoice #2 tx: 0x5121904f9da4e217ca2776ed88f9e51de6b4de5ff3874d9b464942ed95c29ddb (block 3940057)
5. payWithAuthorization (EIP-3009 gasless) tx: 0x45ee12af8dd04574664a77c91ff2714f4f527368a4f6971280dab8f7cfe15380 (block 3940078)
   https://explorer-test.qday.info/tx/0x45ee12af8dd04574664a77c91ff2714f4f527368a4f6971280dab8f7cfe15380
   Signed ReceiveWithAuthorization (from = test wallet, to = InvoiceCheckout, nonce = authorizationNonce(orderId2)
   = 0xd74e0e124cfeda662423392b0e373b0bf36365d5240371436305393471e6d663, validBefore 1795466679);
   eth_call simulation passed before broadcast.
   isPaid -> true; paymentOf -> (payer 0x502D17a8cd1b9024Eab9A036F1EFcD2d48d51b64, paidAt 1795459495, amount 2000000)

Wrong-amount revert: covered by local fork evidence (WrongAmount in fork e2e + fork tests), not re-run on testnet (per plan, no gas burned on reverts).

## Final balances

- tUSD8: 5000000 (unchanged — payer == merchant self-transfers)
- tQDAY: 0.999007416 (total gas for deploy + 5 evidence txs ≈ 0.00099 tQDAY, testnet only; no mainnet assets touched)

## Still missing before DoraHacks submission

- Public GitHub push of commit 57c94261f9ca94a2798f33cc66b5ef1913835875 (machine account darkernity) -> real repo URL for SUBMISSION.md.
- Demo: Vercel deployment of web/ and/or demo video (optional per form, currently local-only).
- Fill GitHub URL + Demo fields in SUBMISSION.md after the two items above, then submit on DoraHacks (deadline 2026-12-11 16:00 HKT; internal target 12-08).

## Verification note (2026-11-24, F-06 recheck)

Review item F-06 claimed the two faucet hashes above were 63 hex chars. Rechecked programmatically on 2026-11-24: every hash string in this file and in SUBMISSION.md is exactly 64 hex chars, and both faucet txs resolve on chain (block 3939805, from faucet 0x10F844B5fFE23414B052f941778Af508D9A1873f). The review's count was taken from ellipsized display forms (0x6d1dce…d498) in its segmented input. No correction needed; F-06 closed as a false alarm with on-chain proof.

## Supplementary evidence — independent roles (2026-11-24, review F-04/F-05/F-14)

The original evidence above used a single wallet by design. The following transactions on the SAME deployed contract close the review's evidence-independence findings. Roles are three distinct wallets:

- Merchant / deployer (W1): 0x502D17a8cd1b9024Eab9A036F1EFcD2d48d51b64 (merchant() of the deployed contract)
- Payer (W2): 0x638AEdE47aDdb6d6DE27bAAD23E939F48c6F1f6C (fresh wallet, funded by W1: 3.00 tUSD8 tx 0xde09603b0c801717b89847f9f39a572c1aa9c38281478b15ae2bd814ba43bacb, 0.05 tQDAY tx 0x311e03d8f3f12769f548833426c891623b6fe801dd1053635e8a5a8557f7c04d)
- Relayer (W3): 0xEAb839A18Bf22008A11177901C14D01A3d83e985 (funded 0.05 tQDAY tx 0xbe6dac67f5eab830c0c889344de08e08d7dc98861fd9b426c3aa13dc1779181d)

### Invoice #3 — independent payer, standard pay (F-04)

orderId 0x9f9f4b53cfa61a5015ae080da63523608f2979b99ad297d6917d5d7e02af4b33 = keccak("aevum-invoice-003"), amount 1250000 (1.25 tUSD8)

- createInvoice tx: 0xa44f63809807ac3235185e27ade67316159c25fe2aa11afcaf8a535b21eea305
- W2 approve tx: 0xc2dd091ba65371181a2669ce146ba6fc90c0b47650ceee47f97314e32950bae2
- W2 pay tx: 0x70c256b93d567d502814068acfdca909c7cd65a0c98869d12c05c8c63826922e (status 0x1)
- paymentOf -> (payer 0x638AEdE47aDdb6d6DE27bAAD23E939F48c6F1f6C, amount 1250000); isPaid -> true
- **Merchant net settlement: W1 tUSD8 balance 2000000 -> 3250000, exactly +1250000** (the buyer-to-merchant net change the review asked for)

### Invoice #4 — gasless pay with a TRUE relayer (F-05)

orderId 0x57810e2586300870cd74a50ffd6105dff871f7623e04c6be781de2f849cba191 = keccak("aevum-invoice-004"), amount 1500000 (1.50 tUSD8)

- createInvoice tx: 0x83298fe136df34d6456f03d57836e1a049d5c66f93af04def622a55a31dbd1a4
- payWithAuthorization tx: 0x196822124b0628354c130c8b6ad158083306d6fbd6b600604b1efdac7491e95b (block 4001982, status success)
- **tx.from = 0xEAb839A18Bf22008A11177901C14D01A3d83e985 (W3, the relayer, paid the gas) while the EIP-3009 signer and recorded payer = 0x638AEdE47aDdb6d6DE27bAAD23E939F48c6F1f6C (W2)** — sender ≠ signer, a real relay
- paymentOf -> (payer W2, amount 1500000); isPaid -> true
- Merchant W1 tUSD8 balance 3250000 -> 4750000, exactly +1500000. W2 tUSD8 final 250000 (3000000 − 1250000 − 1500000, exact)

### Invoice #5 — wrong-amount payment reverts ON TESTNET (F-14)

orderId 0xfb949ac0f76a4f84a19c36019926b9c1f745f87d51e11b7aecb3d3169eb8931c = keccak("aevum-invoice-005"), amount 750000 (0.75 tUSD8)

- createInvoice tx: 0x9f80197311f09f0f913515759dc6abcb0cb0b10d0e4b1023e8bf8cef5423d346
- Wrong-amount pay attempt (740000 instead of 750000) tx: 0xa134579c6192d679677249e170975285f796cf689f23d414505ed4664e3ed84a (block 4001781)
- **Receipt status 0 (failed), gasUsed 26548**; eth_call simulation returns WrongAmount(orderId, 750000, 740000); isPaid(#5) -> false. The headline guarantee "wrong amount always rolls back" is now proven on the target chain, not only on a fork.

Full run log: supplementary-evidence-2026-11-24.log in the build folder.

## Source ↔ bytecode correspondence (2026-11-24, review F-13/F-15)

- **Explorer source verification: PASSED.** Submitted via `forge verify-contract` (Blockscout verifier); the explorer now reports the contract as verified — InvoiceCheckout, solc v0.8.24+commit.e11b9ed9, full 124-line source on the address page: https://explorer-test.qday.info/address/0x35492621EFA400792010757D443dE65dB80A79a0
- **Independent local rebuild comparison:** runtime bytecode rebuilt from the committed source is 2365 bytes, identical in length to the on-chain code; every differing byte lies inside the two immutable slots and equals exactly the constructor values (token 0x456569838f1d43009A91ebA4263147Afd7233483, merchant 0x502D17a8cd1b9024Eab9A036F1EFcD2d48d51b64). No other differences.
- **Clean-checkout `make check`:** a fresh clone of the post-review commit (4c1ffaa, contract source identical to deployed 57c9426) + submodule init + `make install` + `make check` → exit 0: unit 28/28, fork 4/4, typecheck clean. Log: check-clean-checkout.log in the build folder. (The clone was taken from the local repo; the same commit is the one pending publication to the public GitHub repo.)
