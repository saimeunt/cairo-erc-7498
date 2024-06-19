use core::panic_with_felt252;
use snforge_std::{
    test_address, cheat_caller_address, CheatSpan, spy_events, SpyOn, EventSpy, EventAssertions
};
use openzeppelin::tests::utils::constants::{TOKEN_ID, ZERO};
use openzeppelin::token::erc721::ERC721Component;
use cairo_erc_7498::presets::erc721_redeemable_mintable::{
    IERC721RedeemableMintableMixinDispatcherTrait, IERC721RedeemableMintableMixinSafeDispatcherTrait
};
use super::utils::{RedeemablesTestTrait, mint_token};

#[test]
fn test_burn() {
    let redeemables_test = RedeemablesTestTrait::setup();
    let erc721_redeemable_address = *redeemables_test.erc7498_tokens[0];
    let recipient = *redeemables_test.receive_tokens[1];
    mint_token(erc721_redeemable_address, TOKEN_ID, recipient);
    match redeemables_test.erc721_redeemable_safe.burn(TOKEN_ID) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), ERC721Component::Errors::UNAUTHORIZED);
        }
    }
    cheat_caller_address(erc721_redeemable_address, recipient, CheatSpan::TargetCalls(1));
    let mut spy = spy_events(SpyOn::One(erc721_redeemable_address));
    redeemables_test.erc721_redeemable.burn(TOKEN_ID);
    spy
        .assert_emitted(
            @array![
                (
                    erc721_redeemable_address,
                    ERC721Component::Event::Transfer(
                        ERC721Component::Transfer {
                            from: recipient, to: ZERO(), token_id: TOKEN_ID
                        }
                    )
                )
            ]
        );
    match redeemables_test.erc721_redeemable_safe.burn(TOKEN_ID + 1) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), ERC721Component::Errors::INVALID_TOKEN_ID);
        }
    }
    mint_token(erc721_redeemable_address, TOKEN_ID + 1, recipient);
    match redeemables_test.erc721_redeemable_safe.burn(TOKEN_ID + 1) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), ERC721Component::Errors::UNAUTHORIZED);
        }
    }
    cheat_caller_address(erc721_redeemable_address, recipient, CheatSpan::TargetCalls(1));
    redeemables_test.erc721_redeemable.set_approval_for_all(test_address(), true);
    redeemables_test.erc721_redeemable.burn(TOKEN_ID + 1);
    spy
        .assert_emitted(
            @array![
                (
                    erc721_redeemable_address,
                    ERC721Component::Event::Transfer(
                        ERC721Component::Transfer {
                            from: recipient, to: ZERO(), token_id: TOKEN_ID + 1
                        }
                    )
                )
            ]
        );
}
