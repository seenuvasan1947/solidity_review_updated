module battle_addr::cred_token {
    use std::signer;
    use aptos_framework::coin;
    use aptos_framework::string;

    friend battle_addr::streets;

    struct CRED has store {}

    struct CredCapabilities has key {
        mint_cap: coin::MintCapability<CRED>,
        burn_cap: coin::BurnCapability<CRED>,
    }

    fun init_module(sender: &signer) {
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<CRED>(
            sender,
            string::utf8(b"Credibility"),
            string::utf8(b"CRED"),
            8,
            false,
        );
        move_to(sender, CredCapabilities { mint_cap, burn_cap });
        coin::destroy_freeze_cap(freeze_cap);
    }

    public(friend) fun mint(
        module_owner: &signer,
        to: address,
        amount: u64
    ) acquires CredCapabilities {
        let caps = borrow_global<CredCapabilities>(signer::address_of(module_owner));
        let coins = coin::mint<CRED>(amount, &caps.mint_cap);
        if (coin::is_account_registered<CRED>(to)) {
            coin::deposit(to, coins);
        } else {
            coin::destroy_zero(coins);
        };
    }

    public entry fun register(account: &signer) {
        coin::register<CRED>(account);
    }

    public entry fun transfer(from: &signer, to: address, amount: u64) {
        coin::transfer<CRED>(from, to, amount);
    }
}
