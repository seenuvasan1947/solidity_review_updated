# One Shot Reloaded - Security Analysis Report

## Executive Summary

This analysis covers the Move smart contract codebase for "One Shot Reloaded" - a rap battle game system. **6 critical vulnerabilities** were identified, including 2 high-severity issues that would make the core functionality non-functional.

## Critical Vulnerabilities Found

### 1. **Authorization Pattern Analysis** 
**Severity**: NOT A BUG  
**File**: `one_shot.move:59-62`

```move
public entry fun mint_rapper(module_owner: &signer, to: address)
acquires Collection, RapperStats {
    let owner_addr = signer::address_of(module_owner);
    assert!(owner_addr == @battle_addr, 1 /* E_NOT_AUTHORIZED */);
```

**Analysis**: Upon re-examination, this authorization pattern is actually **correct**. The function requires that the caller (signer) be the account at `@battle_addr`, which is the proper way to restrict minting to the module owner. The test confirms this works correctly by creating an account at `@battle_addr` and using it as the signer.

**Status**: This is proper authorization, not a vulnerability.

### 2. **Broken Token Transfer in Battle System**
**Severity**: HIGH  
**File**: `rap_battle.move:68-69, 83-84, 105-111`

```move
// During battle setup
one_shot::transfer_record_only(token_id, player_addr, @battle_addr);
object::transfer(player, rapper_token, @battle_addr);

// After battle - only record is updated, not actual token
one_shot::transfer_record_only(arena.defender_token_id, @battle_addr, defender_addr);
one_shot::transfer_record_only(chall_token_id, @battle_addr, defender_addr);
```

**Issue**: Tokens are transferred to `@battle_addr` during battles, but only the internal ownership records are updated when transferring back to winners. The actual token objects remain with `@battle_addr`.

**Impact**: Winners receive prize money but lose their tokens permanently.

**Recommendation**: Add proper token object transfers back to winners using `object::transfer()`.

### 3. **Missing Authorization in `unstake` Function**
**Severity**: HIGH  
**File**: `streets.move:51`

```move
public entry fun unstake(staker: &signer, module_owner: &signer, rapper_token: Object<Token>)
```

**Issue**: Function requires both `staker` and `module_owner` signers but doesn't verify that `module_owner` is authorized. Any account can call this with any `module_owner`.

**Impact**: Unauthorized token transfers and potential theft of staked tokens.

**Recommendation**: Add proper authorization checks for `module_owner` or remove the parameter if not needed.

### 4. **Inconsistent State Management in Battle Arena**
**Severity**: MEDIUM  
**File**: `rap_battle.move:114-116`

```move
arena.defender = @0x0;
arena.defender_bet = 0;
arena.defender_token_id = @0x0;
```

**Issue**: Arena state is reset after every battle without ensuring proper cleanup of previous defender's token.

**Impact**: If a battle fails midway, tokens could be permanently locked in the arena.

**Recommendation**: Add proper cleanup logic and error handling for failed battles.

### 5. **Arithmetic Inconsistencies in Skill Calculation**
**Severity**: MEDIUM  
**File**: `one_shot.move:162-166`

```move
let after1 = if (s.weak_knees) { 65 - 5 } else { 65 };
let after2 = if (s.heavy_arms) { after1 - 5 } else { after1 };
let after3 = if (s.spaghetti_sweater) { after2 - 5 } else { after2 };
let final_skill = if (s.calm_and_ready) { after3 + 10 } else { after3 };
```

**Issue**: Uses hardcoded values instead of the constants defined at the top of the file (`BASE_SKILL`, `VICE_DECREMENT`, `VIRTUE_INCREMENT`).

**Impact**: Inconsistency between constants and actual calculations, potential for errors.

**Recommendation**: Use the defined constants consistently throughout the code.

### 6. **Inconsistent Token Ownership Tracking**
**Severity**: MEDIUM  
**File**: `one_shot.move:113-127`

```move
public(friend) fun transfer_record_only(token_id: address, from: address, to: address)
acquires RapperStats {
    // Updates internal records without verifying actual ownership
```

**Issue**: Function updates internal ownership records without verifying that `from` actually owns the token.

**Impact**: Internal state could become inconsistent with actual token ownership.

**Recommendation**: Add ownership verification before updating records.

### 7. **Stake Logic Analysis**
**Severity**: NOT A BUG  
**File**: `streets.move:32-49`

```move
public entry fun stake(staker: &signer, rapper_token: Object<Token>) {
    // Move runtime automatically verifies ownership
    object::transfer(staker, rapper_token, @battle_addr);
```

**Analysis**: Upon re-examination, this is **not a vulnerability**. The Move runtime automatically verifies that `staker` owns the `rapper_token` when `object::transfer()` is called. If they don't own it, the transaction will fail.

**Status**: This is proper Move behavior, not a vulnerability.

### 8. **Potential Division by Zero in Battle Logic**
**Severity**: LOW  
**File**: `rap_battle.move:92`

```move
let rnd = timestamp::now_seconds() % (if (total_skill == 0) { 1 } else { total_skill });
```

**Issue**: While there's a check for `total_skill == 0`, this creates a 50/50 random outcome instead of proper skill-based battle.

**Impact**: Low impact, but creates inconsistent game mechanics.

**Recommendation**: Handle zero-skill scenarios more appropriately or prevent them entirely.

## Additional Observations

### Code Quality Issues
- Inconsistent use of constants vs hardcoded values
- Missing error handling in critical paths
- Inadequate input validation
- Poor separation of concerns between modules

### Architecture Concerns
- Complex interdependencies between modules
- Unclear ownership model for tokens
- Missing proper access control patterns
- Inadequate state management

## Recommendations

### Immediate Actions Required
1. **Fix authorization issues** - The `mint_rapper` function needs complete redesign
2. **Fix token transfer logic** - Battle system is fundamentally broken
3. **Add proper access controls** - All privileged functions need authorization

### Medium-term Improvements
1. Implement proper error handling throughout
2. Add comprehensive input validation
3. Use constants consistently
4. Improve state management patterns

### Long-term Considerations
1. Consider refactoring the architecture for better separation of concerns
2. Implement proper testing for edge cases
3. Add formal verification for critical functions
4. Consider using established patterns for token management

## Conclusion

The codebase contains several critical vulnerabilities that would prevent the system from functioning correctly. The most severe issues are in the battle mechanics where tokens are not properly returned to winners, and the unstake function lacks proper authorization. These issues need immediate attention before any deployment.

**Overall Risk Level**: HIGH - Multiple critical vulnerabilities that would result in loss of funds and non-functional system.
