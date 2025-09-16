module battle_addr::streets {
    use std::signer;
    use aptos_framework::event;
    use aptos_framework::object::{Self as object, Object};
    use aptos_framework::timestamp;
    use aptos_token_v2::token::Token;
    use battle_addr::one_shot;
    use battle_addr::cred_token;

    const E_NOT_OWNER: u64 = 1;
    const E_TOKEN_NOT_STAKED: u64 = 2;

    struct StakeInfo has key, store {
        start_time_seconds: u64,
        owner: address,
    }

    #[event]
    struct StakedEvent has drop, store {
        owner: address,
        token_id: address,
        start_time: u64,
    }

    #[event]
    struct UnstakedEvent has drop, store {
        owner: address,
        token_id: address,
        staked_duration: u64,
    }

    public entry fun stake(staker: &signer, rapper_token: Object<Token>) {
        let staker_addr = signer::address_of(staker);
        let token_id = object::object_address(&rapper_token);

        move_to(staker, StakeInfo {
            start_time_seconds: timestamp::now_seconds(),
            owner: staker_addr,
        });

        one_shot::transfer_record_only(token_id, staker_addr, @battle_addr);
        object::transfer(staker, rapper_token, @battle_addr);

        event::emit(StakedEvent {
            owner: staker_addr,
            token_id,
            start_time: timestamp::now_seconds(),
        });
    }

    public entry fun unstake(staker: &signer, module_owner: &signer, rapper_token: Object<Token>) acquires StakeInfo {
        let staker_addr = signer::address_of(staker);
        let token_id = object::object_address(&rapper_token);

        assert!(exists<StakeInfo>(staker_addr), E_TOKEN_NOT_STAKED);
        let stake_info = borrow_global<StakeInfo>(staker_addr);
        assert!(stake_info.owner == staker_addr, E_NOT_OWNER);

        let staked_duration = timestamp::now_seconds() - stake_info.start_time_seconds;
        let days_staked = staked_duration / 86400;

        if (days_staked > 0) {
            let (wk, ha, ss, cr, wins) = one_shot::read_stats(token_id);

            let final_wk = if (days_staked >= 1) { false } else { wk };
            let final_ha = if (days_staked >= 2) { false } else { ha };
            let final_ss = if (days_staked >= 3) { false } else { ss };
            let final_cr = if (days_staked >= 4) { true }  else { cr };

            if (days_staked >= 1) { cred_token::mint(module_owner, staker_addr, 1); };
            if (days_staked >= 2) { cred_token::mint(module_owner, staker_addr, 1); };
            if (days_staked >= 3) { cred_token::mint(module_owner, staker_addr, 1); };
            if (days_staked >= 4) { cred_token::mint(module_owner, staker_addr, 1); };

            one_shot::write_stats(token_id, final_wk, final_ha, final_ss, final_cr, wins);
        };

        let StakeInfo { start_time_seconds: _, owner: _ } = move_from<StakeInfo>(staker_addr);

        one_shot::transfer_record_only(token_id, @battle_addr, staker_addr);
        object::transfer(module_owner, rapper_token, staker_addr);

        event::emit(UnstakedEvent {
            owner: staker_addr,
            token_id,
            staked_duration,
        });
    }
}
