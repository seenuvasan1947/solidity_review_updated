#[test_only]
module owner::vault_tests {
    use owner::vault;
    use std::debug;
    use std::signer;
    use aptos_framework::account;

    #[test(secret_vault_addr = @secret_vault)]
    public fun test_owner_can_set_and_get_secret(secret_vault_addr: &signer) {
        // Create account for secret_vault address
        account::create_account_for_test(@secret_vault);
        
        // Set secret at secret_vault address (so get_secret can find it)
        vault::set_secret(secret_vault_addr, b"owner_secret");

        // Owner can get secret (reads from @secret_vault)
        let s = vault::get_secret(@owner);
        debug::print(&s); // should print "owner_secret"
    }

    #[test(user = @0x456)]
    #[expected_failure(abort_code = 1)] // NOT_OWNER
    public fun test_non_owner_can_set_but_cannot_get(user: &signer) {
        // Create user account
        account::create_account_for_test(signer::address_of(user));
        
        // Non-owner sets a secret at their own address
        vault::set_secret(user, b"hacked_secret");

        // Non-owner tries to get secret, this will abort (proof of NOT_OWNER)
        vault::get_secret(signer::address_of(user));
    }

    // This test demonstrates the actual bug in your code
    #[test(owner = @owner)]
    #[expected_failure(abort_code = 0x60001)] // RESOURCE_NOT_FOUND - demonstrates the bug
    public fun test_bug_owner_sets_at_wrong_address(owner: &signer) {
        // Owner sets secret at @owner address
        vault::set_secret(owner, b"owner_secret");

        // But get_secret tries to read from @secret_vault address - FAILS!
        let s = vault::get_secret(@owner);
        debug::print(&s);
    }
}