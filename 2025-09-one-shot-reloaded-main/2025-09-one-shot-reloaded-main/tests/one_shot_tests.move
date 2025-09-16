#[test_only]
module battle_addr::one_shot_tests {
    use std::signer;
    use aptos_framework::account;
    use battle_addr::one_shot::{Self as one_shot};

    // init_module runs automatically on publish; no manual setup call.

    #[test]
    public fun test_mint_rapper_succeeds() {
        let module_owner = account::create_account_for_test(@battle_addr);
        let minter = account::create_account_for_test(@minter_addr);

        one_shot::mint_rapper(&module_owner, signer::address_of(&minter));

        let minter_address = signer::address_of(&minter);
        let balance = one_shot::balance_of(minter_address);
        assert!(balance == 1, 1);
    }
}
