use cairo_erc_7498::erc7498::interface::{IERC7498_ID, IREDEMPTION_MINTABLE_ID};
use cairo_erc_7498::presets::erc721_redeemable_mintable::IERC721RedeemableMintableMixinDispatcherTrait;
use cairo_erc_7498::presets::erc1155_redeemable_mintable::IERC1155RedeemableMintableMixinDispatcherTrait;
use super::utils::RedeemablesTestTrait;

#[test]
fn test_supports_interface_id() {
    let redeemables_test = RedeemablesTestTrait::setup();
    assert_eq!(redeemables_test.receive_token721.supports_interface(IREDEMPTION_MINTABLE_ID), true);
    assert_eq!(
        redeemables_test.receive_token1155.supports_interface(IREDEMPTION_MINTABLE_ID), true
    );
    assert_eq!(redeemables_test.receive_token721.supports_interface(IERC7498_ID), true);
    assert_eq!(redeemables_test.receive_token1155.supports_interface(IERC7498_ID), true);
}
