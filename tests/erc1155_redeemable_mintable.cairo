use core::panic_with_felt252;
use snforge_std::{
    test_address, cheat_caller_address, CheatSpan, spy_events, SpyOn, EventSpy, EventAssertions
};
use openzeppelin::tests::utils::constants::{TOKEN_ID, ZERO};
use openzeppelin::token::erc1155::ERC1155Component;
use cairo_erc_7498::presets::erc1155_redeemable_mintable::{
    IERC1155RedeemableMintableMixinDispatcherTrait,
    IERC1155RedeemableMintableMixinSafeDispatcherTrait
};
use super::utils::{RedeemablesTestTrait, mint_token};

#[test]
fn test_burn() {
    let redeemables_test = RedeemablesTestTrait::setup();
    let erc1155_redeemable_address = *redeemables_test.erc7498_tokens[1];
    let recipient = *redeemables_test.receive_tokens[1];
    mint_token(erc1155_redeemable_address, TOKEN_ID, recipient);
    match redeemables_test.erc1155_redeemable_safe.burn(test_address(), TOKEN_ID, 1) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), ERC1155Component::Errors::INSUFFICIENT_BALANCE);
        }
    }
    cheat_caller_address(erc1155_redeemable_address, recipient, CheatSpan::TargetCalls(1));
    let mut spy = spy_events(SpyOn::One(erc1155_redeemable_address));
    redeemables_test.erc1155_redeemable.burn(recipient, TOKEN_ID, 1);
    spy
        .assert_emitted(
            @array![
                (
                    erc1155_redeemable_address,
                    ERC1155Component::Event::TransferSingle(
                        ERC1155Component::TransferSingle {
                            operator: recipient, from: recipient, to: ZERO(), id: TOKEN_ID, value: 1
                        }
                    )
                )
            ]
        );
    cheat_caller_address(erc1155_redeemable_address, recipient, CheatSpan::TargetCalls(1));
    match redeemables_test.erc1155_redeemable_safe.burn(recipient, TOKEN_ID + 1, 1) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), ERC1155Component::Errors::INSUFFICIENT_BALANCE);
        }
    }
    mint_token(erc1155_redeemable_address, TOKEN_ID + 1, recipient);
    mint_token(erc1155_redeemable_address, TOKEN_ID + 2, recipient);
    let token_ids = array![TOKEN_ID + 1, TOKEN_ID + 2];
    let values = array![1, 1];
    match redeemables_test
        .erc1155_redeemable_safe
        .batch_burn(recipient, token_ids.span(), values.span()) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), ERC1155Component::Errors::UNAUTHORIZED);
        }
    }
    cheat_caller_address(erc1155_redeemable_address, recipient, CheatSpan::TargetCalls(1));
    redeemables_test.erc1155_redeemable.set_approval_for_all(test_address(), true);
    redeemables_test.erc1155_redeemable.batch_burn(recipient, token_ids.span(), values.span());
    spy
        .assert_emitted(
            @array![
                (
                    erc1155_redeemable_address,
                    ERC1155Component::Event::TransferBatch(
                        ERC1155Component::TransferBatch {
                            operator: test_address(),
                            from: recipient,
                            to: ZERO(),
                            ids: token_ids.span(),
                            values: values.span()
                        }
                    )
                )
            ]
        );
}
