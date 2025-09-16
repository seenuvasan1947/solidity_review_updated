module battle_addr::one_shot {
    use std::signer;
    use std::string;
    use std::option;
    use aptos_framework::event;
    use aptos_framework::object::{Self as object, Object};
    use aptos_token_v2::token::{Self as token};
    use aptos_token_v2::collection;
    use aptos_std::table;

    friend battle_addr::streets;
    friend battle_addr::rap_battle;

    const COLLECTION_NAME: vector<u8> = b"Rappers";
    const COLLECTION_DESCRIPTION: vector<u8> = b"Rappers for the ultimate rap battle.";
    const COLLECTION_URI: vector<u8> = b"https://aptos-rap-battle.dev/rappers";

    struct Collection has key {
        collection: Object<collection::Collection>,
    }

    struct StatsData has store {
        owner: address,
        weak_knees: bool,
        heavy_arms: bool,
        spaghetti_sweater: bool,
        calm_and_ready: bool,
        battles_won: u64,
    }

    struct RapperStats has key {
        stats: table::Table<address, StatsData>,   // token_id -> stats
        owner_counts: table::Table<address, u64>,  // owner -> count
    }

    #[event]
    struct MintRapperEvent has drop, store {
        minter: address,
        token_id: address,
    }

    // MUST be private (module-init hook)
    fun init_module(sender: &signer) {
        let coll_ref = collection::create_unlimited_collection(
            sender,
            string::utf8(COLLECTION_DESCRIPTION),
            string::utf8(COLLECTION_NAME),
            option::none(),
            string::utf8(COLLECTION_URI),
        );
        let coll_obj = object::object_from_constructor_ref<collection::Collection>(&coll_ref);
        move_to(sender, Collection { collection: coll_obj });

        let stats_table = table::new<address, StatsData>();
        let owner_table = table::new<address, u64>();
        move_to(sender, RapperStats { stats: stats_table, owner_counts: owner_table });
    }

    public entry fun mint_rapper(module_owner: &signer, to: address)
    acquires Collection, RapperStats {
        let owner_addr = signer::address_of(module_owner);
        assert!(owner_addr == @battle_addr, 1 /* E_NOT_AUTHORIZED */);

        // 🔧 Lazy-init if needed (unit tests don’t auto-run init_module)
        if (!exists<Collection>(@battle_addr)) {
            init_module(module_owner);
        };
        if (!exists<RapperStats>(@battle_addr)) {
            // This case shouldn’t happen if init_module just ran, but keep it safe.
            let stats_table = table::new<address, StatsData>();
            let owner_table = table::new<address, u64>();
            move_to(module_owner, RapperStats { stats: stats_table, owner_counts: owner_table });
        };

        // Safe to assume collection/stats exist now
        let _ = borrow_global<Collection>(@battle_addr);

        let tok_ref = token::create(
            module_owner,
            string::utf8(COLLECTION_NAME),
            string::utf8(b"A new rapper enters the scene."),
            string::utf8(b"Rapper"),
            option::none(),
            string::utf8(b""),
        );
        let token_obj = object::object_from_constructor_ref<token::Token>(&tok_ref);
        let token_id = object::address_from_constructor_ref(&tok_ref);

        let stats_res = borrow_global_mut<RapperStats>(@battle_addr);
        table::add(&mut stats_res.stats, token_id, StatsData {
            owner: to,
            weak_knees: true,
            heavy_arms: true,
            spaghetti_sweater: true,
            calm_and_ready: false,
            battles_won: 0,
        });
        // increment owner count
        if (table::contains(&stats_res.owner_counts, to)) {
            let cnt = table::borrow_mut(&mut stats_res.owner_counts, to);
            *cnt = *cnt + 1;
        } else {
            table::add(&mut stats_res.owner_counts, to, 1);
        };

        event::emit(MintRapperEvent { minter: to, token_id });

        object::transfer(module_owner, token_obj, to);
    }

    // ===== friend helpers & utils (unchanged) =====

    public(friend) fun transfer_record_only(token_id: address, from: address, to: address)
    acquires RapperStats {
        let stats_res = borrow_global_mut<RapperStats>(@battle_addr);
        let s = table::borrow_mut(&mut stats_res.stats, token_id);
        s.owner = to;
        let c_from = table::borrow_mut(&mut stats_res.owner_counts, from);
        *c_from = *c_from - 1;
        if (*c_from == 0) { table::remove(&mut stats_res.owner_counts, from); };
        if (table::contains(&stats_res.owner_counts, to)) {
            let c_to = table::borrow_mut(&mut stats_res.owner_counts, to);
            *c_to = *c_to + 1;
        } else {
            table::add(&mut stats_res.owner_counts, to, 1);
        };
    }

    public(friend) fun read_stats(token_id: address): (bool, bool, bool, bool, u64)
    acquires RapperStats {
        let stats_res = borrow_global<RapperStats>(@battle_addr);
        let s = table::borrow(&stats_res.stats, token_id);
        (s.weak_knees, s.heavy_arms, s.spaghetti_sweater, s.calm_and_ready, s.battles_won)
    }

    public(friend) fun write_stats(
        token_id: address,
        weak_knees: bool,
        heavy_arms: bool,
        spaghetti_sweater: bool,
        calm_and_ready: bool,
        battles_won: u64
    ) acquires RapperStats {
        let stats_res = borrow_global_mut<RapperStats>(@battle_addr);
        let s = table::borrow_mut(&mut stats_res.stats, token_id);
        s.weak_knees = weak_knees;
        s.heavy_arms = heavy_arms;
        s.spaghetti_sweater = spaghetti_sweater;
        s.calm_and_ready = calm_and_ready;
        s.battles_won = battles_won;
    }

    public(friend) fun increment_wins(token_id: address) acquires RapperStats {
        let stats_res = borrow_global_mut<RapperStats>(@battle_addr);
        let s = table::borrow_mut(&mut stats_res.stats, token_id);
        s.battles_won = s.battles_won + 1;
    }

    public(friend) fun skill_of(token_id: address): u64 acquires RapperStats {
        let stats_res = borrow_global<RapperStats>(@battle_addr);
        let s = table::borrow(&stats_res.stats, token_id);
        let after1 = if (s.weak_knees) { 65 - 5 } else { 65 };
        let after2 = if (s.heavy_arms) { after1 - 5 } else { after1 };
        let after3 = if (s.spaghetti_sweater) { after2 - 5 } else { after2 };
        let final_skill = if (s.calm_and_ready) { after3 + 10 } else { after3 };
        final_skill
    }

    public fun balance_of(addr: address): u64 acquires RapperStats {
        if (!exists<RapperStats>(@battle_addr)) return 0;
        let stats_res = borrow_global<RapperStats>(@battle_addr);
        if (table::contains(&stats_res.owner_counts, addr)) {
            *table::borrow(&stats_res.owner_counts, addr)
        } else {
            0
        }
    }
}
