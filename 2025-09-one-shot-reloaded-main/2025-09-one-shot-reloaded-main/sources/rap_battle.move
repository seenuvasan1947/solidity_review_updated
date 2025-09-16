module battle_addr::rap_battle {
    use std::signer;
    use aptos_framework::event;
    use aptos_framework::object::{Self as object, Object};
    use aptos_framework::coin::{Self as coin, Coin};
    use aptos_framework::timestamp;
    use aptos_token_v2::token::Token;
    use battle_addr::cred_token;
    use battle_addr::one_shot;

    const E_BATTLE_ARENA_OCCUPIED: u64 = 1;
    const E_BETS_DO_NOT_MATCH: u64 = 2;

    const BASE_SKILL: u64 = 65;
    const VICE_DECREMENT: u64 = 5;
    const VIRTUE_INCREMENT: u64 = 10;

    struct BattleArena has key {
        defender: address,
        defender_bet: u64,
        defender_token_id: address,
        prize_pool: Coin<cred_token::CRED>,
    }

    #[event]
    struct OnStage has drop, store {
        defender: address,
        token_id: address,
        cred_bet: u64,
    }

    #[event]
    struct Battle has drop, store {
        challenger: address,
        challenger_token_id: address,
        winner: address,
    }

    // MUST be private
    fun init_module(sender: &signer) {
        move_to(sender, BattleArena {
            defender: @0x0,
            defender_bet: 0,
            defender_token_id: @0x0,
            prize_pool: coin::zero<cred_token::CRED>(),
        });
    }

    public entry fun go_on_stage_or_battle(
        player: &signer,
        rapper_token: Object<Token>,
        bet_amount: u64
    ) acquires BattleArena {
        let player_addr = signer::address_of(player);
        let arena = borrow_global_mut<BattleArena>(@battle_addr);

        if (arena.defender == @0x0) {
            assert!(arena.defender_bet == 0, E_BATTLE_ARENA_OCCUPIED);
            arena.defender = player_addr;
            arena.defender_bet = bet_amount;

            let token_id = object::object_address(&rapper_token);
            arena.defender_token_id = token_id;

            let first_bet = coin::withdraw<cred_token::CRED>(player, bet_amount);
            coin::merge(&mut arena.prize_pool, first_bet);

            one_shot::transfer_record_only(token_id, player_addr, @battle_addr);
            object::transfer(player, rapper_token, @battle_addr);

            event::emit(OnStage {
                defender: player_addr,
                token_id,
                cred_bet: bet_amount,
            });

        } else {
            assert!(arena.defender_bet == bet_amount, E_BETS_DO_NOT_MATCH);
            let defender_addr = arena.defender;
            let chall_addr = player_addr;

            let chall_token_id = object::object_address(&rapper_token);
            one_shot::transfer_record_only(chall_token_id, chall_addr, @battle_addr);
            object::transfer(player, rapper_token, @battle_addr);

            let chall_coins = coin::withdraw<cred_token::CRED>(player, bet_amount);
            coin::merge(&mut arena.prize_pool, chall_coins);

            let defender_skill = one_shot::skill_of(arena.defender_token_id);
            let challenger_skill = one_shot::skill_of(chall_token_id);
            let total_skill = defender_skill + challenger_skill;
            let rnd = timestamp::now_seconds() % (if (total_skill == 0) { 1 } else { total_skill });
            let winner = if (rnd < defender_skill) { defender_addr } else { chall_addr };

            event::emit(Battle {
                challenger: chall_addr,
                challenger_token_id: chall_token_id,
                winner,
            });

            let pool = coin::extract_all(&mut arena.prize_pool);
            if (winner == defender_addr) {
                coin::deposit(defender_addr, pool);
                one_shot::increment_wins(arena.defender_token_id);
                one_shot::transfer_record_only(arena.defender_token_id, @battle_addr, defender_addr);
                one_shot::transfer_record_only(chall_token_id, @battle_addr, defender_addr);
            } else {
                coin::deposit(chall_addr, pool);
                one_shot::increment_wins(chall_token_id);
                one_shot::transfer_record_only(arena.defender_token_id, @battle_addr, chall_addr);
                one_shot::transfer_record_only(chall_token_id, @battle_addr, chall_addr);
            };

            arena.defender = @0x0;
            arena.defender_bet = 0;
            arena.defender_token_id = @0x0;
        }
    }
}
