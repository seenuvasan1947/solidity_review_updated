# OneShot: Reloaded

[//]: # (contest-details-open)

## About the Project

**RapBattle** is a playful on-chain protocol on **Aptos** that lets players mint “Rapper” NFTs, stake them to train away vices, and then battle head-to-head with on-chain bets using a custom fungible token (**CRED**).

Core ideas:

* **Rapper NFTs (Token V2 / Objects):** One-click mint from the `Rappers` collection. Each token has *logical* stats (tracked in a resource table) that affect battle outcomes.
* **Staking (“Streets”):** Stake a Rapper to the protocol to gradually remove vices and earn **CRED** per full day staked.
* **Battles:** Two players match equal **CRED** bets; the protocol computes outcome from the Rapper stats; the winner receives the prize pool, and the winner’s Rapper accrues a win.
* **Credibility Token (CRED):** Simple `Coin<CRED>` with module-owned mint/burn capabilities; used for staking rewards and battle wagers.

This repo targets **Aptos CLI 7.7.0** and the current `mainnet` revisions of `aptos-framework` and `aptos-token-objects`. It is designed to compile and run with a single unit test out of the box.

---

## Actors

Actors:

* **Module Owner (`@battle_addr`):**

  * Publishes modules and owns the **CRED** mint/burn capabilities.
  * Can call `mint_rapper` (enforced: only `@battle_addr` as signer).
  * Centralization risk: can mint arbitrary **CRED** and **Rapper** NFTs.
* **Player / Holder (any address):**

  * Receives/mints **Rapper** NFTs (via module owner).
  * Stakes Rapper NFTs in `streets` to improve stats and earn **CRED**.
  * Uses **CRED** to place battle wagers.
* **Defender / Challenger (players in `rap_battle`):**

  * **Defender** takes the stage first with a bet; **Challenger** matches the bet to initiate a battle.
  * The winner receives the **CRED** prize pool and the win is recorded on the winning Rapper.

Centralization and limitations:

* **Mint authority:** `@battle_addr` controls the **CRED** supply and the minting of new Rappers.
* **Custody during battles/staking:** The protocol **custodies** NFTs at `@battle_addr` during staking and battles. The code updates an internal ownership registry (resource table). Actual object transfers out from `@battle_addr` require its signer; the sample battle flow updates records and deposits prize tokens but does not physically transfer the NFTs post-battle.
* **RNG:** Battle randomness is derived from `timestamp::now_seconds()`.

[//]: # (contest-details-close)
[//]: # (scope-open)

## Scope (contracts)

```
├── sources
│   └── cred_token.move
│   └── one_shot.move
│   └── streets.move
│   └── rap_battle.move
```

Key design notes for auditors:

* **Stats storage**: Instead of per-token property maps, Rapper stats are recorded in a `RapperStats` resource (two `Table`s) under `@battle_addr`. Access outside `one_shot` happens only through `public(friend)` helpers.
* **Friends**: `streets` and `rap_battle` are declared `friend` of `one_shot` to call those helpers; they **do not** read/write `RapperStats` fields directly.
* **Coins**: `CRED` follows standard `aptos_framework::coin` patterns. No `copy`/`drop` on `Coin<T>`; merging and `extract_all` are used correctly.

## Compatibilities

Compatibilities:

* **Blockchains:**

  * Aptos (devnet/testnet/mainnet) using **Aptos CLI 7.7.0**.
* **Token standards / packages:**

  * **Aptos Token V2 / TokenObjects** for NFTs (collection + token creation via `ConstructorRef` → `Object`).
  * **Aptos Framework `coin`** for fungible **CRED**.
* **Addresses / Config:**

  * `aptos_token_v2 = "0x4"` (official Token V2 address).
  * Dependencies pinned to `mainnet` revs (see `Move.toml`).

[//]: # (scope-close)
[//]: # (getting-started-open)

## Setup

### Prereqs

* **Aptos CLI 7.7.0**
* Rust toolchain (transitively required by CLI)

### Build & Test

Clone and run:

```bash
# from repo root
aptos move clean
aptos move test --dev
```

Expected result:

* Builds the `AptosFramework`, `AptosTokenObjects`, and this package.
* Runs `tests/one_shot_tests.move` which mints a Rapper and verifies balance via the `one_shot::balance_of` view. Test should pass.

### Project Layout & Notes

* `Move.toml` pins:

  * `AptosFramework` and `AptosTokenObjects` (subdir `aptos-move/framework/aptos-token-objects`) at `rev = "mainnet"`.
  * `aptos_token_v2` address at `0x4`.
* **Module initialization**:

  * Functions literally named `init_module` are **private** per Move rules.
  * `one_shot::mint_rapper` **lazy-initializes** the collection/tables during tests or first use.
* **Commands you might use while auditing**:

  ```bash
  aptos move compile --dev
  aptos move test --dev
  aptos move prove --dev  # if you want to run the Move Prover (additional setup required)
  ```

[//]: # (getting-started-close)
[//]: # (known-issues-open)

## Known Issues

None reported!

[//]: # (known-issues-close)
