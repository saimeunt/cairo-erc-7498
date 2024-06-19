use starknet::ContractAddress;
use starknet::get_block_timestamp;
use snforge_std::{declare, ContractClassTrait, test_address, cheat_block_timestamp_global};
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin::tests::utils::constants::{NAME, SYMBOL, BASE_URI, ZERO};
use openzeppelin::introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use openzeppelin::token::erc721::interface::IERC721_ID;
use openzeppelin::token::erc1155::interface::IERC1155_ID;
use cairo_erc_7498::erc7498::redeemables_constants::BURN_ADDRESS;
use cairo_erc_7498::erc7498::redeemables_structs::{
    TraitRedemption, CampaignParams, CampaignRequirements, Campaign
};
use cairo_erc_7498::utils::consideration_enums::ItemType;
use cairo_erc_7498::utils::consideration_structs::{
    OfferItem, OfferItemTrait, ConsiderationItem, ConsiderationItemTrait
};
use cairo_erc_7498::presets::erc721_redeemable_mintable::{
    IERC721RedeemableMintableMixinDispatcher, IERC721RedeemableMintableMixinDispatcherTrait,
    IERC721RedeemableMintableMixinSafeDispatcher, IERC721RedeemableMintableMixinSafeDispatcherTrait
};
use cairo_erc_7498::presets::erc1155_redeemable_mintable::{
    IERC1155RedeemableMintableMixinDispatcher, IERC1155RedeemableMintableMixinDispatcherTrait,
    IERC1155RedeemableMintableMixinSafeDispatcher,
    IERC1155RedeemableMintableMixinSafeDispatcherTrait
};

fn is_erc721(token: ContractAddress) -> bool {
    ISRC5Dispatcher { contract_address: token }.supports_interface(IERC721_ID)
}

fn is_erc1155(token: ContractAddress) -> bool {
    ISRC5Dispatcher { contract_address: token }.supports_interface(IERC1155_ID)
}

pub fn mint_token(token: ContractAddress, token_id: u256, recipient: ContractAddress) {
    if is_erc721(token) {
        IERC721RedeemableMintableMixinDispatcher { contract_address: token }
            .mint(recipient, token_id);
    } else {
        IERC1155RedeemableMintableMixinDispatcher { contract_address: token }
            .mint(recipient, token_id, 1);
    }
}

#[derive(Copy, Drop)]
pub struct RedeemablesTest {
    pub erc7498_tokens: Span<ContractAddress>,
    pub erc721_redeemable: IERC721RedeemableMintableMixinDispatcher,
    pub erc721_redeemable_safe: IERC721RedeemableMintableMixinSafeDispatcher,
    pub erc1155_redeemable: IERC1155RedeemableMintableMixinDispatcher,
    pub erc1155_redeemable_safe: IERC1155RedeemableMintableMixinSafeDispatcher,
    pub receive_tokens: Span<ContractAddress>,
    pub receive_token721: IERC721RedeemableMintableMixinDispatcher,
    pub receive_token721_safe: IERC721RedeemableMintableMixinSafeDispatcher,
    pub receive_token1155: IERC1155RedeemableMintableMixinDispatcher,
    pub receive_token1155_safe: IERC1155RedeemableMintableMixinSafeDispatcher,
    pub default_campaign_offer: Span<OfferItem>,
    pub default_campaign_consideration: Span<ConsiderationItem>,
    pub default_trait_redemptions: Span<TraitRedemption>
}

#[generate_trait]
pub impl RedeemablesTestImpl of RedeemablesTestTrait {
    fn setup() -> RedeemablesTest {
        cheat_block_timestamp_global(1000);

        let erc721_redeemable_contract = declare("ERC721RedeemableMintable").unwrap();
        let mut erc721_redeemable_calldata = array![];
        erc721_redeemable_calldata.append_serde(NAME());
        erc721_redeemable_calldata.append_serde(SYMBOL());
        erc721_redeemable_calldata.append_serde(BASE_URI());
        let (erc721_redeemable_contract_address, _) = erc721_redeemable_contract
            .deploy(@erc721_redeemable_calldata)
            .unwrap();
        let erc721_redeemable = IERC721RedeemableMintableMixinDispatcher {
            contract_address: erc721_redeemable_contract_address
        };
        let erc721_redeemable_safe = IERC721RedeemableMintableMixinSafeDispatcher {
            contract_address: erc721_redeemable_contract_address
        };
        let erc1155_redeemable_contract = declare("ERC1155RedeemableMintable").unwrap();
        let mut erc1155_redeemable_calldata = array![];
        erc1155_redeemable_calldata.append_serde(BASE_URI());
        let (erc1155_redeemable_contract_address, _) = erc1155_redeemable_contract
            .deploy(@erc1155_redeemable_calldata)
            .unwrap();
        let erc1155_redeemable = IERC1155RedeemableMintableMixinDispatcher {
            contract_address: erc1155_redeemable_contract_address
        };
        let erc1155_redeemable_safe = IERC1155RedeemableMintableMixinSafeDispatcher {
            contract_address: erc1155_redeemable_contract_address
        };

        // Not using internal burn needs approval for the contract itself to transfer tokens on users' behalf.
        erc721_redeemable.set_approval_for_all(erc721_redeemable_contract_address, true);
        erc1155_redeemable.set_approval_for_all(erc1155_redeemable_contract_address, true);

        let mut erc7498_tokens = array![];
        erc7498_tokens.append(erc721_redeemable_contract_address);
        erc7498_tokens.append(erc1155_redeemable_contract_address);

        let (receive_token721_contract_address, _) = erc721_redeemable_contract
            .deploy(@erc721_redeemable_calldata)
            .unwrap();
        let receive_token721 = IERC721RedeemableMintableMixinDispatcher {
            contract_address: erc721_redeemable_contract_address
        };
        let receive_token721_safe = IERC721RedeemableMintableMixinSafeDispatcher {
            contract_address: erc721_redeemable_contract_address
        };
        let (receive_token1155_contract_address, _) = erc1155_redeemable_contract
            .deploy(@erc1155_redeemable_calldata)
            .unwrap();
        let receive_token1155 = IERC1155RedeemableMintableMixinDispatcher {
            contract_address: erc1155_redeemable_contract_address
        };
        let receive_token1155_safe = IERC1155RedeemableMintableMixinSafeDispatcher {
            contract_address: erc1155_redeemable_contract_address
        };

        let mut receive_tokens = array![];
        receive_tokens.append(receive_token721_contract_address);
        receive_tokens.append(receive_token1155_contract_address);

        receive_token721.set_redeemables_contracts(erc7498_tokens.span());
        assert_eq!(receive_token721.get_redeemables_contracts(), erc7498_tokens.span());
        receive_token1155.set_redeemables_contracts(erc7498_tokens.span());
        assert_eq!(receive_token1155.get_redeemables_contracts(), erc7498_tokens.span());

        let single_erc721_offer = OfferItemTrait::empty()
            .with_item_type(ItemType::ERC721)
            .with_amount(1);
        let default_erc721_campaign_offer = single_erc721_offer
            .with_token(receive_token721_contract_address)
            .with_item_type(ItemType::ERC721_WITH_CRITERIA);
        let default_campaign_offer = array![default_erc721_campaign_offer];

        let single_erc721_consideration = ConsiderationItemTrait::empty()
            .with_item_type(ItemType::ERC721)
            .with_amount(1);
        let default_erc721_campaign_consideration = single_erc721_consideration
            .with_token(erc721_redeemable_contract_address)
            .with_recipient(BURN_ADDRESS())
            .with_item_type(ItemType::ERC721_WITH_CRITERIA);
        let default_campaign_consideration = array![default_erc721_campaign_consideration];

        let default_trait_redemptions = array![];

        RedeemablesTest {
            erc7498_tokens: erc7498_tokens.span(),
            erc721_redeemable,
            erc721_redeemable_safe,
            erc1155_redeemable,
            erc1155_redeemable_safe,
            receive_tokens: receive_tokens.span(),
            receive_token721,
            receive_token721_safe,
            receive_token1155,
            receive_token1155_safe,
            default_campaign_offer: default_campaign_offer.span(),
            default_campaign_consideration: default_campaign_consideration.span(),
            default_trait_redemptions: default_trait_redemptions.span(),
        }
    }

    fn get_campaign_consideration_item(
        self: @RedeemablesTest, token: ContractAddress
    ) -> ConsiderationItem {
        let consideration_item = *self.default_campaign_consideration[0];
        let item_type = if is_erc721(token) {
            ItemType::ERC721_WITH_CRITERIA
        } else {
            ItemType::ERC1155_WITH_CRITERIA
        };
        consideration_item.with_token(token).with_item_type(item_type)
    }

    fn get_campaign_with_consideration_item(
        self: @RedeemablesTest, consideration_item: ConsiderationItem
    ) -> Campaign {
        let requirements = array![
            CampaignRequirements {
                offer: *self.default_campaign_offer,
                consideration: array![consideration_item].span(),
                trait_redemptions: *self.default_trait_redemptions,
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
        Campaign { params, requirements: requirements.span() }
    }
}
