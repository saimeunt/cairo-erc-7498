use core::panic_with_felt252;
use starknet::ContractAddress;
use starknet::get_block_timestamp;
use snforge_std::test_address;
use openzeppelin::tests::utils::constants::ZERO;
use cairo_erc_7498::utils::consideration_structs::ConsiderationItemTrait;
use cairo_erc_7498::erc7498::redeemables_errors::Errors;
use cairo_erc_7498::erc7498::redeemables_structs::{Campaign, CampaignParams, CampaignRequirements};
use cairo_erc_7498::erc7498::interface::{
    IERC7498MixinDispatcher, IERC7498MixinDispatcherTrait, IERC7498MixinSafeDispatcher,
    IERC7498MixinSafeDispatcherTrait,
};
use super::utils::{RedeemablesTest, RedeemablesTestTrait};

fn get_and_update_campaign(
    redeemables_test: @RedeemablesTest, erc7498_token_address: ContractAddress,
) {
    let erc7498_token = IERC7498MixinDispatcher { contract_address: erc7498_token_address };
    let erc7498_token_safe = IERC7498MixinSafeDispatcher {
        contract_address: erc7498_token_address
    };

    // Should revert if the campaign does not exist.
    let mut i = 0;
    while i < 3 {
        match erc7498_token_safe.get_campaign(i) {
            Result::Ok(_) => panic_with_felt252('FAIL'),
            Result::Err(panic_data) => {
                assert_eq!(*panic_data.at(0), Errors::INVALID_CAMPAIGN_ID);
            }
        }
        i += 1;
    };

    let consideration = array![
        redeemables_test.get_campaign_consideration_item(erc7498_token_address),
    ];
    let requirements = array![
        CampaignRequirements {
            offer: *redeemables_test.default_campaign_offer,
            consideration: consideration.span(),
            trait_redemptions: *redeemables_test.default_trait_redemptions,
        }
    ];
    let timestamp = get_block_timestamp();
    let params = CampaignParams {
        start_time: timestamp,
        end_time: timestamp + 1000,
        max_campaign_redemptions: 5,
        manager: test_address(),
        signer: ZERO(),
    };

    let mut campaign = Campaign { params, requirements: requirements.span() };
    let campaign_id = erc7498_token.create_campaign(campaign, "test123");

    let (_got_campaign, metadata_uri, total_redemptions) = erc7498_token.get_campaign(campaign_id);
    // assert_eq!(got_campaign, campaign);
    assert_eq!(metadata_uri, "test123");
    assert_eq!(total_redemptions, 0);

    // Should revert if the campaign does not exist.
    match erc7498_token_safe.get_campaign(campaign_id + 1) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => { assert_eq!(*panic_data.at(0), Errors::INVALID_CAMPAIGN_ID); }
    }

    // Should revert if trying to get campaign id 0, since it starts at 1.
    match erc7498_token_safe.get_campaign(0) {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => { assert_eq!(*panic_data.at(0), Errors::INVALID_CAMPAIGN_ID); }
    }

    // Should revert if updating an invalid campaign id.
    match erc7498_token_safe.update_campaign(0, campaign, "test111") {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => { assert_eq!(*panic_data.at(0), Errors::INVALID_CAMPAIGN_ID); }
    }
    match erc7498_token_safe.update_campaign(campaign_id + 1, campaign, "test111") {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => { assert_eq!(*panic_data.at(0), Errors::INVALID_CAMPAIGN_ID); }
    }

    // Update the campaign.
    campaign.params.end_time = 0;
    campaign.params.manager = ZERO();
    // Should expect revert with InvalidTime since endTime > startTime.
    match erc7498_token_safe.update_campaign(campaign_id, campaign, "test456") {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => { assert_eq!(*panic_data.at(0), Errors::INVALID_TIME); }
    }

    campaign.params.start_time = 0;
    erc7498_token.update_campaign(campaign_id, campaign, "test456");

    let (_got_campaign, metadata_uri, total_redemptions) = erc7498_token.get_campaign(campaign_id);
    // assert_eq!(got_campaign, campaign);
    assert_eq!(metadata_uri, "test456");
    assert_eq!(total_redemptions, 0);

    // Updating the campaign again should fail since the manager is now the null address.
    match erc7498_token_safe.update_campaign(campaign_id, campaign, "test456") {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => { assert_eq!(*panic_data.at(0), Errors::NOT_MANAGER); }
    }
}

#[test]
fn test_get_and_update_campaign() {
    let redeemables_test = RedeemablesTestTrait::setup();
    let mut i = 0;
    while i < redeemables_test
        .erc7498_tokens
        .len() {
            let erc7498_token_address = *redeemables_test.erc7498_tokens[i];
            get_and_update_campaign(@redeemables_test, erc7498_token_address);
            i += 1;
        };
}

fn campaign_reverts(redeemables_test: @RedeemablesTest, erc7498_token_address: ContractAddress,) {
    let erc7498_token_safe = IERC7498MixinSafeDispatcher {
        contract_address: erc7498_token_address
    };

    let mut campaign = redeemables_test
        .get_campaign_with_consideration_item(
            redeemables_test
                .get_campaign_consideration_item(erc7498_token_address)
                .with_recipient(ZERO())
        );
    match erc7498_token_safe.create_campaign(campaign, "test123") {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(
                *panic_data.at(0), Errors::CONSIDERATION_ITEM_RECIPIENT_CANNOT_BE_ZERO_ADDRESS
            );
        }
    }

    campaign = redeemables_test
        .get_campaign_with_consideration_item(
            redeemables_test.get_campaign_consideration_item(erc7498_token_address).with_amount(0)
        );
    match erc7498_token_safe.create_campaign(campaign, "test123") {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), Errors::CONSIDERATION_ITEM_AMOUNT_CANNOT_BE_ZERO);
        }
    }

    campaign = redeemables_test
        .get_campaign_with_consideration_item(
            redeemables_test
                .get_campaign_consideration_item(erc7498_token_address)
                .with_end_amount(2)
        );
    match erc7498_token_safe.create_campaign(campaign, "test123") {
        Result::Ok(_) => panic_with_felt252('FAIL'),
        Result::Err(panic_data) => {
            assert_eq!(*panic_data.at(0), Errors::NON_MATCHING_CONSIDERATION_ITEM_AMOUNTS);
        }
    }
}

#[test]
fn test_campaign_reverts() {
    let redeemables_test = RedeemablesTestTrait::setup();
    let mut i = 0;
    while i < redeemables_test
        .erc7498_tokens
        .len() {
            let erc7498_token_address = *redeemables_test.erc7498_tokens[i];
            campaign_reverts(@redeemables_test, erc7498_token_address);
            i += 1;
        };
}
