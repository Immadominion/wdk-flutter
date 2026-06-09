# WDK for Flutter — Template Wallet Roadmap

> **Project:** `wdk-starter-flutter` — a production-ready Flutter **Template Wallet** that **integrates Tether's existing WDK** (the JS Bare worklet) via a new `flutter_bare_kit` binding, mirroring the official React Native starter.
> **Author:** Dominion Nwakanma ([github.com/Immadominion](https://github.com/Immadominion) · [web3flutter.dev](https://www.web3flutter.dev/))
> **Bounty:** Tether "Template Wallet" — [tether.dev/grants/bounties/2800541287](https://tether.dev/grants/bounties/2800541287/) · **4,000 USD₮** · applications close **Jun 24, 2026**
> **License:** Apache-2.0 (matches upstream WDK)
> **Status:** Planning → scaffolding. This document is the execution plan and doubles as the **M1 architecture deliverable**. It intentionally contains **no code**.

---

## 0. Executive summary

The bounty asks for a **template wallet that integrates the WDK** for a framework WDK doesn't yet cover. We target **Flutter**. The PDF is explicit on two points that define the architecture: *"Each template must integrate the WDK… use the worklet as the secure execution layer,"* and *"Modifications to WDK core SDK… are out of scope."*

Therefore we **do not reimplement WDK**. Instead we build the missing piece that lets Flutter integrate it: a **`flutter_bare_kit`** plugin that embeds Holepunch's Bare runtime (the same native layer `react-native-bare-kit` uses) and runs Tether's **unmodified** `@tetherto/pear-wrk-wdk` worklet bundle. On top of it we build a **`wdk_flutter`** provider (the Flutter analog of `wdk-react-native-provider`, exposing `WDKService` + a `useWallet()`-equivalent) and a **`wdk-starter-flutter`** app mirroring the RN starter screen-for-screen. Because we reuse Tether's real worklet, **every chain WDK already supports — Bitcoin, Lightning (Spark), Ethereum, Polygon, Arbitrum, Plasma, Solana — works without us writing chain code.**

Delivery follows the bounty's three milestones: **M1** proposal & architecture (this doc, 20%), **M2** working prototype with WDK integration + core flows (40%), **M3** final template + docs + demo video + PR to the Tether repo (40%).

---

## 1. Bounty requirements (source of truth: `Template-Wallet.pdf`)

**In scope:**
- A production-ready template that integrates **WDK + Indexer API** and demonstrates core flows: onboarding, balance display, send/receive, transaction history, multi-chain.
- **Auth & security:** secure seed-phrase generation, storage, recovery, validation.
- **Wallet management:** multiple wallets per user; multiple accounts per wallet.
- **Assets:** BTC, USD₮, XAU₮. **Networks:** Bitcoin, **Lightning (Spark)**, Ethereum, Polygon, Arbitrum, **Plasma**, Solana.
- **Transactions:** history with filtering; status monitoring. **Send/receive:** manual / paste / QR-scan recipient; automatic address-format validation.
- **Docs** (setup, architecture, framework-specific integration notes) + a **2–5 min demo video**.
- PDF note: *use the worklet for seed/key custody, signing, account/wallet ops, and config-driven multi-chain flows; the app layer handles UX, history, monitoring.*

**Out of scope (do not build):** polished production design systems; advanced DeFi (swaps, bridges, staking, lending); backend / custom indexer; **modifications to WDK core or Indexer source**.

**Deliverables:** **public** GitHub repo with complete source; documentation; demo video; a **Pull Request into the Tether repo** (templates/examples section).

**Acceptance / definition of done:** runs on the framework's **latest stable** version; WDK correctly integrated for creation, balance queries, signing, transactions; core flows functional and demonstrated; **docs clear enough for an external dev to set up and extend within 30 minutes**; demo video proves end-to-end; clean, modular, well-named code.

**Milestones & payout:** M1 Proposal & Architecture Review — **20%**; M2 Core Integration & Wallet Flows (working prototype: SDK integration, onboarding, balances, send/receive) — **40%**; M3 Final Delivery (complete template, docs, demo, PR) — **40%**.

**Applicant requirements:** production experience in the framework; familiarity with wallet concepts (key management, multi-chain); portfolio/OSS depth. *(All three are strongly met — see `GRANT_APPLICATION.md`.)*

---

## 2. How the React Native starter works (the pattern we mirror)

From the reference (`wdk-starter-react-native/`):
- The app depends on `@tetherto/wdk-react-native-provider` + `@tetherto/wdk-uikit-react-native` + pricing packages.
- The provider internally runs `@tetherto/pear-wrk-wdk` inside `react-native-bare-kit` — a **Bare worklet** that owns seeds/keys and does all signing **off the UI thread**.
- The app talks to the worklet only through the provider's public surface:
  - **`WDKService`**: `initialize()`, `createSeed({prf})→mnemonic`, `quoteSendByNetwork(net, accIdx, amount, recipient, asset)→fee`, `sendByNetwork(...)→{hash, fee}`, `getDenominationValue(token)`.
  - **`useWallet()`**: `wallet`, `isInitialized`, `isUnlocked`, `isLoading`, `balances{list,isLoading}`, `addresses`, `transactions{list,isLoading}`, `createWallet({name, mnemonic?})`, `unlockWallet()→bool`, `refreshWalletBalance()`, `clearWallet()`.
  - **Config**: `{ indexer:{apiKey,url}, chains, enableCaching }`; theming `{ defaultMode, brandConfig:{primaryColor} }`.
  - **Enums**: `NetworkType` (ethereum, polygon, arbitrum, ton, tron, solana, segwit, lightning + **plasma** per the bounty), `AssetTicker` (btc, usdt, xaut).
  - **Error codec**: `"code:X,msg:Y"` (code `13` = biometric cancelled).
- The chains config (`src/config/get-chains-config.ts`) is plain data (RPC URLs, bundler/paymaster, EntryPoint v0.7, Safe modules 0.3.0, Electrum host, etc.) — we **reuse this verbatim** as Dart config; we change none of it.

**Our job is to reproduce that three-layer split in Flutter:** Bare worklet (unchanged) ↔ `flutter_bare_kit` (new) ↔ `wdk_flutter` provider (new) ↔ app (new).

---

## 3. Architecture

```
┌───────────────────────────────────────────────┐
│ apps/wdk_starter_flutter  (go_router + screens) │  ← UX, history, monitoring
├───────────────────────────────────────────────┤
│ packages/wdk_ui    (themeable widgets, optional)│
├───────────────────────────────────────────────┤
│ packages/wdk_flutter  (Riverpod provider)       │  ← WDKService + useWallet(), config, RPC client
│   • bare-rpc / IPC message layer                │
│   • maps the worklet's RPC surface to Dart      │
├───────────────────────────────────────────────┤
│ packages/flutter_bare_kit  (Flutter plugin)     │  ← loads & runs the worklet, IPC pipe
│   • Dart API (Worklet.start / IPC stream)       │
│   • Android: CMake/NDK build of bare-kit        │
│   • iOS: podspec building/linking bare-kit      │
├───────────────────────────────────────────────┤
│ @tetherto/pear-wrk-wdk  (UNMODIFIED JS bundle)  │  ← Tether's real WDK core (all chains)
└───────────────────────────────────────────────┘
```

### 3.1 `packages/flutter_bare_kit` — the missing binding
A Flutter plugin that mirrors `react-native-bare-kit`'s native layer (which vendors Bare's C/Obj-C/Java sources and builds them via `cmake-fetch` + `bare-link`; no prebuilt npm artifact).
- **Dart API:** `Worklet` (`start(filename, source/bundle)`, `suspend/resume`, `terminate`) + an `IPC` duplex exposed as a Dart `Stream<Uint8List>` + `write()`. Mirrors the RN API so the protocol ports unchanged.
- **Android:** an Android library module compiling `bare-kit`'s native sources via CMake/NDK, exposing a thin JNI surface to the Dart side over platform channels (or FFI to the C layer). Reuse `bare-kit`'s `android/` sources as the reference.
- **iOS:** a CocoaPods podspec building/linking `bare-kit`'s `apple/` sources (BareWorklet/BareIPC), bridged to Dart.
- **Worklet bundle delivery:** bundle `@tetherto/pear-wrk-wdk/bundle/wdk-worklet.mobile.bundle.js` as a Flutter asset and load it at runtime. We do **not** rebuild or modify it.

### 3.2 `packages/wdk_flutter` — the provider
The Flutter analog of `wdk-react-native-provider`.
- Starts the worklet via `flutter_bare_kit` at `initialize()`, holds the IPC/`bare-rpc` client.
- Exposes **`WdkService`** (the facade above) and **Riverpod providers** reproducing `useWallet()` 1:1 (`walletProvider`, `isInitializedProvider`, `isUnlockedProvider`, `balancesProvider`, `addressesProvider`, `transactionsProvider`, + `WalletNotifier` with `createWallet/unlockWallet/refreshWalletBalance/clearWallet`).
- **Config**: a `WdkConfig` (indexer apiKey/url, chains map, enableCaching) supplied via `ProviderScope` overrides — same shape as the RN `config` prop, reusing the RN chains config values verbatim.
- **Key custody & device integration**: seed/keys live in the worklet (per the PDF). The provider wires the device pieces the worklet needs: secure storage (`flutter_secure_storage` ↔ Keychain/Keystore), biometrics (`local_auth`), device id for the `prf`, and re-serializes errors to `"code:X,msg:Y"`.

### 3.3 `packages/wdk_ui` — themeable widgets (lightweight)
A small Flutter widget kit (`WdkThemeProvider` + `WdkTheme` ThemeExtension, `Balance`, `TransactionList`, `AssetSelector`, `NetworkSelector`, `AddressInput`, `AmountInput`, `QrCode`, `SeedPhrase`) mirroring `wdk-uikit-react-native`. Scoped modestly because the PDF excludes "polished design systems"; goal is clean, reusable, themeable — not a full design system.

### 3.4 `apps/wdk_starter_flutter` — the template
go_router route tree mirroring the RN expo-router screens: `/` gate, `/onboarding`, `/wallet-setup/{name,secure,confirm,complete,import,import-name}`, `/authorize`, `/wallet`, `/assets`, `/activity`, `/token-details`, `/send/{select-token,select-network,details}`, `/receive/{select-token,select-network,details}`, `/scan-qr`, `/settings`. Each screen calls the provider/`WdkService` exactly where the RN screen calls its equivalent.

### 3.5 Monorepo
A **Melos** workspace (`melos.yaml` + Dart pub workspace). Packages path-linked during dev. CI runs analyze/format/test across all packages. Apache-2.0 throughout.

---

## 4. The critical-path unknown: the worklet's RPC protocol

The worklet (`pear-wrk-wdk`) and the RN provider talk over an IPC/`bare-rpc` protocol that isn't publicly documented. Resolving it is the **single most important early task** and the main M2 risk.

**Discovery plan (all read-only, no WDK modifications):**
1. `npm install` the RN starter and **read the installed `@tetherto/wdk-react-native-provider` dist** to extract the exact RPC method names, request/response shapes, and how it frames messages over `react-native-bare-kit`'s IPC.
2. **Read the `@tetherto/pear-wrk-wdk` bundle** (it's JS) to confirm the handler names/contract from the worklet side.
3. Reproduce that protocol in `wdk_flutter`'s RPC client.
4. If anything is ambiguous, ask Tether (the proposal explicitly notes this dependency — a reasonable, in-scope clarification, not a core modification).

This is well-bounded: the protocol is observable in shipped JS, and `bare-rpc` is an open Holepunch package.

---

## 5. Verification strategy (we reuse the real core, so we verify integration, not parity)

Because signing/custody run in Tether's unmodified worklet, correctness reduces to **"is the binding faithful?"**:
- **Binding smoke tests:** `flutter_bare_kit` loads the WDK bundle, IPC round-trips bytes, worklet boots and responds.
- **Cross-implementation check:** the **same mnemonic** produces the **same addresses** in the RN starter and the Flutter app (it must — same worklet). A small fixture compares Flutter-app-derived addresses against the RN app for the in-scope networks.
- **Flow tests:** create/import wallet, unlock (biometric), fetch balances (Indexer), quote + send on testnet, see history update.
- **E2E:** `integration_test` + **patrol** (handles native biometric/camera dialogs) across onboarding → create → confirm → unlock → send/receive.

---

## 6. Quality gates
- Unit/widget tests across packages; golden tests for `wdk_ui` (light/dark/brand).
- `dart analyze` + `dart format --set-exit-if-changed`; Melos-aggregated; GitHub Actions CI.
- Per-package `example/` + the full starter app.
- Security review of key handling: seeds/keys never leave the worklet; device storage via Keychain/Keystore; biometrics via `local_auth`; no secrets in logs/errors.
- Accessibility pass (Semantics, tap targets, contrast).
- **Docs measured against the bounty's 30-minute-setup bar** (a clean-machine run-through).

---

## 7. Risk register

| Risk | Severity | Mitigation |
|---|---|---|
| **`flutter_bare_kit` native build** (Android NDK/CMake + iOS podspec for Bare) — no existing Flutter binding | High | Mirror `react-native-bare-kit`'s vendored native sources + `cmake-fetch`/`bare-link` setup; build Android first (NDK), then iOS; smoke-test IPC before anything else; this binding is the keystone task in M2 |
| **Undocumented worklet RPC protocol** | High | Extract from the installed provider dist + worklet bundle (§4); fall back to a targeted Tether question |
| **Worklet bundle compatibility** (mobile bundle expects RN-bare-kit host quirks) | Medium | Use the same `.mobile.bundle.js`; replicate `react-native-bare-kit`'s IPC framing exactly; pin the `pear-wrk-wdk` version |
| **Plasma network support in current WDK build** | Low/Med | It's the worklet's responsibility; confirm the bundled WDK version exposes Plasma; if not, demonstrate the listed networks the bundle supports and note version dependency |
| **iOS/Android crypto + Bare runtime size/perf** | Low/Med | Bare is designed for embedding; worklet runs off the UI thread; benchmark in CI |
| **Indexer API key availability** | Low | Optional for dev (public RPCs / mock data); request key in parallel; needed only for live balances |
| **30-min-setup doc bar** | Low | Treat docs as a deliverable from day one; clean-machine test before M3 |

---

## 8. Phase plan (mapped to bounty milestones)

**Phase 0 — Bootstrap (now).** Melos monorepo; `flutter_bare_kit` (plugin), `wdk_flutter` (package), `wdk_ui` (package), `apps/wdk_starter_flutter` scaffolded and path-linked; Apache-2.0 LICENSE; README; CI (analyze/format/test); go_router shell with the screen routes; theming; provider API surface stubbed. **Public repo from day one.**
*Exit:* `melos bootstrap` + analyze/test green; the app runs and navigates the screen skeleton on iOS+Android.

**Phase M1 — Proposal & Architecture Review (20%).** This roadmap + the framework-selection rationale + the integration plan, submitted with the application. Includes the RPC-discovery plan and the native-binding design.
*Exit:* Tether approves the architecture.

**Phase M2 — Core Integration & Wallet Flows (40%).** Build `flutter_bare_kit` (Android then iOS) until it loads `pear-wrk-wdk` and IPC round-trips. Extract + implement the worklet RPC in `wdk_flutter`. Wire `WdkService`/`useWallet()`. Implement onboarding → create/import (seed gen/recovery/validation) → unlock → balances (Indexer) → send/receive (manual/paste/QR + validation) on at least the EVM + BTC paths. Pricing for USD values.
*Exit:* a **working prototype** that creates/imports a wallet, shows live balances, and completes a testnet send; same-mnemonic→same-address check passes vs the RN starter; one patrol E2E green.

**Phase M3 — Final Delivery (40%).** Complete the remaining in-scope networks the worklet supports (Solana, Plasma, Lightning/Spark, Polygon, Arbitrum); multi-wallet + multi-account; tx history filtering + status monitoring; finish `wdk_ui`; full screen parity with the RN starter; docs (setup + architecture + integration notes, 30-min bar); **2–5 min demo video**; open the **PR to the Tether repo**.
*Exit:* all acceptance criteria met; PR submitted; demo video published.

---

## 9. Pre-flight / open items
- [x] Bounty is **open** (applications close Jun 24, 2026); reward **4,000 USD₮**; milestone-based.
- [ ] Submit the application (`GRANT_APPLICATION.md`) before **Jun 24** — the proposal IS the M1 deliverable.
- [ ] `npm install` the RN starter to extract the worklet RPC protocol (§4) — first build task.
- [ ] Request the **WDK Indexer API key** (and optional Tron key) — needed only for live balances in M2+.
- [ ] Confirm the bundled WDK version's **Plasma** support.
- [ ] Confirm with Tether the preferred repo/PR target (templates/examples section) and naming (`wdk-starter-flutter`).

## Appendix — references
- RN starter (pattern to mirror): `wdk-starter-react-native/` (this workspace) · [github.com/tetherto/wdk-starter-react-native](https://github.com/tetherto/wdk-starter-react-native)
- WDK docs: [docs.wdk.tether.io](https://docs.wdk.tether.io/) · core on npm: `@tetherto/wdk-core`
- Bare embedding: [holepunchto/bare-kit](https://github.com/holepunchto/bare-kit) · [holepunchto/react-native-bare-kit](https://github.com/holepunchto/react-native-bare-kit) · `bare-rpc`, `bare-link`
- Worklet bundle: `@tetherto/pear-wrk-wdk` (consumed unmodified)
- Flutter native interop: Dart FFI / platform channels; `local_auth`, `flutter_secure_storage`
