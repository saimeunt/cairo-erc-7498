//! Component implementing IERC7498.

#[starknet::component]
pub mod ERC7498Component {
    use core::panic_with_felt252;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use starknet::contract_address_const;
    use starknet::get_block_timestamp;
    use openzeppelin::introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin::introspection::src5::SRC5Component::SRC5;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc1155::dual1155::{DualCaseERC1155, DualCaseERC1155Trait};
    use openzeppelin::token::erc20::dual20::{DualCaseERC20, DualCaseERC20Trait};
    use openzeppelin::token::erc721::dual721::{DualCaseERC721, DualCaseERC721Trait};
    // use cairo_erc_7496::erc7496::interface::{IERC7496Dispatcher, IERC7496DispatcherTrait};
    use cairo_erc_7498::utils::consideration_enums::ItemType;
    use cairo_erc_7498::utils::consideration_structs::{OfferItem, ConsiderationItem};
    use cairo_erc_7498::erc7498::redeemables_constants::BURN_ADDRESS;
    use cairo_erc_7498::erc7498::redeemables_errors::Errors;
    use cairo_erc_7498::erc7498::redeemables_structs::{
        TraitRedemption, Campaign, CampaignStorage, CampaignParams, CampaignRequirements,
        CampaignRequirementsStorage
    };
    use cairo_erc_7498::erc7498::interface::{
        IERC7498, IERC7498_ID, IRedemptionMintableDispatcher, IRedemptionMintableDispatcherTrait,
        IERC721BurnableDispatcher, IERC721BurnableDispatcherTrait, IERC1155BurnableDispatcher,
        IERC1155BurnableDispatcherTrait, IERC20BurnableDispatcher, IERC20BurnableDispatcherTrait
    };

    #[storage]
    struct Storage {
        /// @dev Counter for next campaign id.
        ERC7498_next_campaign_id: u256,
        /// @dev The campaign by campaign id.
        ERC7498_campaigns: LegacyMap<u256, CampaignStorage>,
        ERC7498_requirements: LegacyMap<(u256, u32), CampaignRequirementsStorage>,
        ERC7498_offer: LegacyMap<(u256, u32, u32), OfferItem>,
        ERC7498_consideration: LegacyMap<(u256, u32, u32), ConsiderationItem>,
        ERC7498_trait_redemptions: LegacyMap<(u256, u32, u32), TraitRedemption>,
        /// @dev The campaign URIs by campaign id.
        ERC7498_campaign_uris: LegacyMap<u256, ByteArray>,
        /// @dev The total current redemptions by campaign id.
        ERC7498_total_redemptions: LegacyMap<u256, u256>,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {
        CampaignUpdated: CampaignUpdated,
        Redemption: Redemption
    }

    /// Emitted when `campaign_id` campaign is updated.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct CampaignUpdated {
        #[key]
        pub campaign_id: u256,
        pub campaign: Campaign,
        pub uri: ByteArray
    }

    /// Emitted when a redemption happens for `campaign_id`.
    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct Redemption {
        #[key]
        pub campaign_id: u256,
        pub requirements_index: u256,
        pub redemption_hash: felt252,
        pub consideration_token_ids: Span<u256>,
        pub trait_redemption_token_ids: Span<u256>,
        pub redeemed_by: ContractAddress
    }

    //
    // External
    //

    #[embeddable_as(ERC7498Impl)]
    impl ERC7498<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of IERC7498<ComponentState<TContractState>> {
        fn get_campaign(
            self: @ComponentState<TContractState>, campaign_id: u256
        ) -> (Campaign, ByteArray, u256) {
            // Revert if campaign id is invalid.
            assert(
                campaign_id != 0 && campaign_id < self.ERC7498_next_campaign_id.read(),
                Errors::INVALID_CAMPAIGN_ID
            );
            (
                // Get the campaign.
                self._read_campaign(campaign_id),
                // Get the campaign URI.
                self.ERC7498_campaign_uris.read(campaign_id),
                // Get the total redemptions.
                self.ERC7498_total_redemptions.read(campaign_id)
            )
        }

        fn update_campaign(
            ref self: ComponentState<TContractState>,
            campaign_id: u256,
            campaign: Campaign,
            uri: ByteArray
        ) {
            // Revert if the campaign id is invalid.
            assert(
                campaign_id != 0 && campaign_id < self.ERC7498_next_campaign_id.read(),
                Errors::INVALID_CAMPAIGN_ID
            );
            // Revert if msg.sender is not the manager.
            let existing_manager = self._read_campaign(campaign_id).params.manager;
            assert(existing_manager == get_caller_address(), Errors::NOT_MANAGER);
            // Validate the campaign params and revert if invalid.
            self._validate_campaign(@campaign);
            // Set the campaign.
            self._write_campaign(campaign_id, @campaign);
            // Update the campaign uri if it was provided.
            if (uri.len() != 0) {
                self.ERC7498_campaign_uris.write(campaign_id, uri.clone());
            }
            self.emit(CampaignUpdated { campaign_id, campaign: campaign.clone(), uri });
        }

        fn redeem(
            ref self: ComponentState<TContractState>,
            consideration_token_ids: Span<u256>,
            recipient: ContractAddress,
            extra_data: Span<felt252>
        ) {
            // If the recipient is the null address, set to msg.sender.
            let actual_recipient = if recipient == contract_address_const::<0>() {
                get_caller_address()
            } else {
                recipient
            };
            // Get the values from extraData.
            let campaign_id: u256 = (*extra_data.at(0)).try_into().unwrap();
            let requirements_index: u32 = (*extra_data.at(1)).try_into().unwrap();
            let trait_redemptions_len: u32 = (*extra_data.at(2)).try_into().unwrap();
            let mut trait_redemption_token_ids = array![];
            let mut i = 0;
            while i < trait_redemptions_len {
                let token_id: u256 = (*extra_data.at(i + 3)).try_into().unwrap();
                trait_redemption_token_ids.append(token_id);
                i += 1;
            };
            // Get the campaign.
            let campaign = self._read_campaign(campaign_id);
            // Validate the requirements index is valid.
            assert(
                requirements_index < campaign.requirements.len(),
                Errors::REQUIREMENTS_INDEX_OUT_OF_BOUNDS
            );
            // Validate the campaign time and total redemptions.
            self._validate_redemption(campaign_id, @campaign);
            // Process the redemption.
            self
                ._process_redemption(
                    campaign_id,
                    // requirements_index.try_into().unwrap(),
                    campaign.requirements[requirements_index],
                    consideration_token_ids,
                    trait_redemption_token_ids.span(),
                    actual_recipient
                );
            // Emit the Redemption event.
            self
                .emit(
                    Redemption {
                        campaign_id,
                        requirements_index: requirements_index.into(),
                        redemption_hash: 0,
                        consideration_token_ids,
                        trait_redemption_token_ids: trait_redemption_token_ids.span(),
                        redeemed_by: get_caller_address()
                    }
                );
        }
    }

    //
    // Internal
    //

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        /// Initializes the contract by setting next campaign id
        /// This should only be used inside the contract's constructor.
        fn initializer(ref self: ComponentState<TContractState>) {
            self.ERC7498_next_campaign_id.write(1);
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IERC7498_ID);
        }

        fn _create_campaign(
            ref self: ComponentState<TContractState>, campaign: @Campaign, uri: ByteArray
        ) -> u256 {
            // Validate the campaign params, reverts if invalid.
            self._validate_campaign(campaign);
            // Set the campaignId and increment the next one.
            let campaign_id = self.ERC7498_next_campaign_id.read();
            self.ERC7498_next_campaign_id.write(campaign_id + 1);
            // Set the campaign params.
            self._write_campaign(campaign_id, campaign);
            // Set the campaign URI.
            self.ERC7498_campaign_uris.write(campaign_id, uri.clone());
            self.emit(CampaignUpdated { campaign_id, campaign: campaign.clone(), uri });
            campaign_id
        }

        fn _read_offer(
            self: @ComponentState<TContractState>,
            campaign_id: u256,
            requirements_index: u32,
            offer_len: u32
        ) -> Span<OfferItem> {
            let mut offer = array![];
            let mut i = 0;
            while i < offer_len {
                let offer_item = self.ERC7498_offer.read((campaign_id, requirements_index, i));
                offer.append(offer_item);
                i += 1;
            };
            offer.span()
        }

        fn _read_consideration(
            self: @ComponentState<TContractState>,
            campaign_id: u256,
            requirements_index: u32,
            consideration_len: u32
        ) -> Span<ConsiderationItem> {
            let mut consideration = array![];
            let mut i = 0;
            while i < consideration_len {
                let consideration_item = self
                    .ERC7498_consideration
                    .read((campaign_id, requirements_index, i));
                consideration.append(consideration_item);
                i += 1;
            };
            consideration.span()
        }

        fn _read_trait_redemptions(
            self: @ComponentState<TContractState>,
            campaign_id: u256,
            requirements_index: u32,
            trait_redemptions_len: u32
        ) -> Span<TraitRedemption> {
            let mut trait_redemptions = array![];
            let mut i = 0;
            while i < trait_redemptions_len {
                let trait_redemptions_item = self
                    .ERC7498_trait_redemptions
                    .read((campaign_id, requirements_index, i));
                trait_redemptions.append(trait_redemptions_item);
                i += 1;
            };
            trait_redemptions.span()
        }

        fn _read_requirements(
            self: @ComponentState<TContractState>, campaign_id: u256, requirements_len: u32
        ) -> Span<CampaignRequirements> {
            let mut requirements = array![];
            let mut i = 0;
            while i < requirements_len {
                let requirement: CampaignRequirementsStorage = self
                    .ERC7498_requirements
                    .read((campaign_id, i));
                requirements
                    .append(
                        CampaignRequirements {
                            offer: self._read_offer(campaign_id, i, requirement.offer_len),
                            consideration: self
                                ._read_consideration(campaign_id, i, requirement.consideration_len),
                            trait_redemptions: self
                                ._read_trait_redemptions(
                                    campaign_id, i, requirement.trait_redemptions_len
                                )
                        }
                    );
                i += 1;
            };
            requirements.span()
        }

        fn _read_campaign(self: @ComponentState<TContractState>, campaign_id: u256) -> Campaign {
            let campaign: CampaignStorage = self.ERC7498_campaigns.read(campaign_id);
            Campaign {
                params: campaign.params,
                requirements: self._read_requirements(campaign_id, campaign.requirements_len),
            }
        }

        fn _write_offer(
            ref self: ComponentState<TContractState>,
            campaign_id: u256,
            requirements_index: u32,
            offer: Span<OfferItem>
        ) {
            let mut i = 0;
            while i < offer
                .len() {
                    let offer_item = *offer[i];
                    self.ERC7498_offer.write((campaign_id, requirements_index, i), offer_item);
                    i += 1;
                };
        }

        fn _write_consideration(
            ref self: ComponentState<TContractState>,
            campaign_id: u256,
            requirements_index: u32,
            consideration: Span<ConsiderationItem>
        ) {
            let mut i = 0;
            while i < consideration
                .len() {
                    let consideration_item = *consideration[i];
                    self
                        .ERC7498_consideration
                        .write((campaign_id, requirements_index, i), consideration_item);
                    i += 1;
                };
        }

        fn _write_trait_redemptions(
            ref self: ComponentState<TContractState>,
            campaign_id: u256,
            requirements_index: u32,
            trait_redemptions: Span<TraitRedemption>
        ) {
            let mut i = 0;
            while i < trait_redemptions
                .len() {
                    let trait_redemptions_item = *trait_redemptions[i];
                    self
                        .ERC7498_trait_redemptions
                        .write((campaign_id, requirements_index, i), trait_redemptions_item);
                    i += 1;
                };
        }

        fn _write_requirements(
            ref self: ComponentState<TContractState>,
            campaign_id: u256,
            requirements: Span<CampaignRequirements>
        ) {
            let mut i = 0;
            while i < requirements
                .len() {
                    let requirement = *requirements[i];
                    self
                        .ERC7498_requirements
                        .write(
                            (campaign_id, i),
                            CampaignRequirementsStorage {
                                offer_len: requirement.offer.len(),
                                consideration_len: requirement.consideration.len(),
                                trait_redemptions_len: requirement.trait_redemptions.len()
                            }
                        );
                    self._write_offer(campaign_id, i, requirement.offer);
                    self._write_consideration(campaign_id, i, requirement.consideration);
                    self._write_trait_redemptions(campaign_id, i, requirement.trait_redemptions);
                    i += 1;
                };
        }

        fn _write_campaign(
            ref self: ComponentState<TContractState>, campaign_id: u256, campaign: @Campaign
        ) {
            let requirements = *campaign.requirements;
            self
                .ERC7498_campaigns
                .write(
                    campaign_id,
                    CampaignStorage {
                        params: *campaign.params, requirements_len: requirements.len(),
                    }
                );
            self._write_requirements(campaign_id, requirements);
        }

        fn _validate_campaign(self: @ComponentState<TContractState>, campaign: @Campaign) {
            // Revert if startTime is past endTime.
            assert(*campaign.params.start_time <= *campaign.params.end_time, Errors::INVALID_TIME);
            // Iterate over the requirements.
            let requirements = *campaign.requirements;
            let mut i = 0;
            while i < requirements
                .len() {
                    let requirement: CampaignRequirements = *requirements[i];
                    let mut j: u32 = 0;
                    // Validate each consideration item.
                    while j < requirement
                        .consideration
                        .len() {
                            let consideration: ConsiderationItem = *requirement.consideration[j];
                            // Revert if any of the consideration item recipients is the zero address.
                            // 0xdead address should be used instead.
                            // For internal burn, override _internalBurn and set _useInternalBurn to true.
                            assert(
                                consideration.recipient != contract_address_const::<0>(),
                                Errors::CONSIDERATION_ITEM_RECIPIENT_CANNOT_BE_ZERO_ADDRESS
                            );
                            assert(
                                consideration.start_amount != 0,
                                Errors::CONSIDERATION_ITEM_AMOUNT_CANNOT_BE_ZERO
                            );
                            // Revert if startAmount != endAmount, as this requires more complex logic.
                            assert(
                                consideration.start_amount == consideration.end_amount,
                                Errors::NON_MATCHING_CONSIDERATION_ITEM_AMOUNTS
                            );
                            j += 1;
                        };
                    i += 1;
                };
        }

        fn _validate_redemption(
            ref self: ComponentState<TContractState>, campaign_id: u256, campaign: @Campaign
        ) {
            let start_time = *campaign.params.start_time;
            let end_time = *campaign.params.end_time;
            assert(!self._is_inactive(start_time, end_time), Errors::NOT_ACTIVE);
            let total_redemptions = self.ERC7498_total_redemptions.read(campaign_id);
            let max_campaign_redemptions = (*campaign.params.max_campaign_redemptions).into();
            assert(
                total_redemptions + 1 <= max_campaign_redemptions,
                Errors::MAX_CAMPAIGN_REDEMPTIONS_REACHED
            );
        }

        fn _transfer_consideration_item(
            self: @ComponentState<TContractState>, id: u256, consideration_item: ConsiderationItem
        ) {
            // WITH_CRITERIA with identifier 0 is wildcard: any id is valid.
            // Criteria is not yet implemented, for that functionality use the contract offerer.
            if id != consideration_item.identifier_or_criteria
                && consideration_item.identifier_or_criteria != 0 {
                assert(
                    consideration_item.item_type == ItemType::ERC721_WITH_CRITERIA
                        && consideration_item.item_type == ItemType::ERC1155_WITH_CRITERIA,
                    Errors::INVALID_CONSIDERATION_TOKEN_ID_SUPPLIED
                );
            }
            // Transfer the token to the consideration recipient.
            match consideration_item.item_type {
                ItemType::NATIVE => {
                    // Not implemented
                    panic_with_felt252('Not implemented');
                },
                ItemType::ERC721 |
                ItemType::ERC721_WITH_CRITERIA => {
                    if consideration_item.recipient == BURN_ADDRESS() {
                        let token = IERC721BurnableDispatcher {
                            contract_address: consideration_item.token
                        };
                        token.burn(id);
                    } else {
                        let token = DualCaseERC721 { contract_address: consideration_item.token };
                        token
                            .safe_transfer_from(
                                get_caller_address(),
                                consideration_item.recipient,
                                id,
                                array![].span()
                            );
                    }
                },
                ItemType::ERC1155 |
                ItemType::ERC1155_WITH_CRITERIA => {
                    if consideration_item.recipient == BURN_ADDRESS() {
                        let token = IERC1155BurnableDispatcher {
                            contract_address: consideration_item.token
                        };
                        token.burn(get_caller_address(), id, consideration_item.start_amount);
                    } else {
                        let token = DualCaseERC1155 { contract_address: consideration_item.token };
                        token
                            .safe_transfer_from(
                                get_caller_address(),
                                consideration_item.recipient,
                                id,
                                consideration_item.start_amount,
                                array![].span()
                            );
                    }
                },
                ItemType::ERC20 => {
                    if consideration_item.recipient == BURN_ADDRESS() {
                        let token = IERC20BurnableDispatcher {
                            contract_address: consideration_item.token
                        };
                        token.burn(get_caller_address(), consideration_item.start_amount);
                    } else {
                        let token = DualCaseERC20 { contract_address: consideration_item.token };
                        token
                            .transfer_from(
                                get_caller_address(),
                                consideration_item.recipient,
                                consideration_item.start_amount
                            );
                    }
                }
            };
        }

        fn _is_inactive(
            self: @ComponentState<TContractState>, start_time: u64, end_time: u64
        ) -> bool {
            let timestamp = get_block_timestamp();
            timestamp < start_time || timestamp > end_time
        }

        fn _process_redemption(
            ref self: ComponentState<TContractState>,
            campaign_id: u256,
            requirements: @CampaignRequirements,
            consideration_token_ids: Span<u256>,
            trait_redemption_token_ids: Span<u256>,
            recipient: ContractAddress
        ) {
            // Increment the campaign's total redemptions.
            let total_redemptions = self.ERC7498_total_redemptions.read(campaign_id);
            self.ERC7498_total_redemptions.write(campaign_id, total_redemptions + 1);
            if (*requirements.trait_redemptions).len() > 0 {
                // Process the trait redemptions.
                self
                    ._process_trait_redemptions(
                        *requirements.trait_redemptions, trait_redemption_token_ids
                    );
            }
            if (*requirements.consideration).len() > 0 {
                // Process the consideration items.
                self
                    ._process_consideration_items(
                        *requirements.consideration, consideration_token_ids
                    );
            }
            if (*requirements.offer).len() > 0 {
                // Process the offer items.
                self
                    ._process_offer_items(
                        campaign_id,
                        *requirements.consideration,
                        *requirements.offer,
                        *requirements.trait_redemptions,
                        recipient
                    );
            }
        }

        fn _process_consideration_items(
            self: @ComponentState<TContractState>,
            consideration: Span<ConsiderationItem>,
            consideration_token_ids: Span<u256>
        ) {
            // Revert if the tokenIds length does not match the consideration length.
            assert(
                consideration.len() == consideration_token_ids.len(),
                Errors::TOKEN_IDS_DONT_MATCH_CONSIDERATION_LENGTH
            );
            // Iterate over the consideration items.
            let mut i = 0;
            while i < consideration
                .len() {
                    // Get the consideration item.
                    let consideration_item: ConsiderationItem = *consideration[i];
                    // Get the identifier.
                    let id = *consideration_token_ids[i];
                    // Get the token balance.
                    let mut balance: u256 = 0;
                    match consideration_item.item_type {
                        ItemType::NATIVE => {
                            // Not implemented
                            panic_with_felt252('Not implemented');
                        },
                        ItemType::ERC721 |
                        ItemType::ERC721_WITH_CRITERIA => {
                            let token = DualCaseERC721 {
                                contract_address: consideration_item.token
                            };
                            balance =
                                if token.owner_of(id) == get_caller_address() {
                                    1
                                } else {
                                    0
                                };
                        },
                        ItemType::ERC1155 |
                        ItemType::ERC1155_WITH_CRITERIA => {
                            let token = DualCaseERC1155 {
                                contract_address: consideration_item.token
                            };
                            balance = token.balance_of(get_caller_address(), id);
                        },
                        ItemType::ERC20 => {
                            let token = DualCaseERC20 {
                                contract_address: consideration_item.token
                            };
                            balance = token.balance_of(get_caller_address());
                        }
                    };
                    // Ensure the balance is sufficient.
                    assert(
                        balance >= consideration_item.start_amount,
                        Errors::CONSIDERATION_ITEM_INSUFFICIENT_BALANCE
                    );
                    // Transfer the consideration item.
                    self._transfer_consideration_item(id, consideration_item);
                    i += 1;
                };
        }

        fn _process_trait_redemptions(
            self: @ComponentState<TContractState>,
            trait_redemptions: Span<TraitRedemption>,
            trait_redemption_token_ids: Span<u256>
        ) {
            assert(
                trait_redemptions.len() == trait_redemption_token_ids.len(),
                Errors::TRAIT_REDEMPTION_TOKEN_IDS_DONT_MATCH_TRAIT_REDEMPTIONS_LENGTH
            );
            self._set_traits(trait_redemptions, trait_redemption_token_ids);
        }

        fn _process_offer_items(
            self: @ComponentState<TContractState>,
            campaign_id: u256,
            consideration: Span<ConsiderationItem>,
            offer: Span<OfferItem>,
            trait_redemptions: Span<TraitRedemption>,
            recipient: ContractAddress
        ) {
            // Mint the new tokens.
            let mut i = 0;
            while i < offer
                .len() {
                    let offer_item: OfferItem = *offer[i];
                    let redemption = IRedemptionMintableDispatcher {
                        contract_address: offer_item.token
                    };
                    redemption
                        .mint_redemption(
                            campaign_id, recipient, offer_item, consideration, trait_redemptions
                        );
                    i += 1;
                };
        }

        fn _set_traits(
            self: @ComponentState<TContractState>,
            trait_redemptions: Span<TraitRedemption>,
            trait_redemption_token_ids: Span<u256>
        ) {
            // Iterate over the trait redemptions and set traits on the tokens.
            let mut i = 0;
            while i < trait_redemptions
                .len() {
                    // Get the trait redemption identifier and place on the stack.
                    let _identifier = *trait_redemption_token_ids[i];
                    let trait_redemptions_item: TraitRedemption = *trait_redemptions[i];
                    // Get the substandard and place on the stack.
                    let substandard = trait_redemptions_item.substandard;
                    // Get the substandard value and place on the stack.
                    let substandard_value: u256 = trait_redemptions_item.substandard_value.into();
                    // Get the token and place on the stack.
                    let _token = trait_redemptions_item.token;
                    // Get the trait key and place on the stack.
                    let _trait_key = trait_redemptions_item.trait_key;
                    // Get the trait value and place on the stack.
                    let trait_value: u256 = trait_redemptions_item.trait_value.into();
                    // Get the current trait value and place on the stack.
                    // let dispatcher = IERC7496Dispatcher { contract_address: token };
                    // let current_trait_value: u256 = dispatcher
                    //     .get_trait_value(identifier, trait_key)
                    //     .into();
                    let current_trait_value: u256 = 0;
                    // If substandard is 1, set trait to traitValue.
                    if substandard == 1 {
                        // Revert if the current trait value does not match the substandard value.
                        assert(
                            current_trait_value == substandard_value,
                            Errors::INVALID_REQUIRED_TRAIT_VALUE
                        );
                    // Set the trait to the trait value.
                    // IERC7496(token).setTrait(identifier, traitRedemptions[i].traitKey, traitValue);
                    } else if substandard == 2 {
                        // Revert if the current trait value is greater than the substandard value.
                        assert(
                            current_trait_value <= substandard_value,
                            Errors::INVALID_REQUIRED_TRAIT_VALUE
                        );
                        // Increment the trait by the trait value.
                        let _new_trait_value = current_trait_value + trait_value;
                    // IERC7496(token).setTrait(identifier, traitRedemptions[i].traitKey, bytes32(newTraitValue));
                    } else if substandard == 3 {
                        // Revert if the current trait value is less than the substandard value.
                        assert(
                            current_trait_value >= substandard_value,
                            Errors::INVALID_REQUIRED_TRAIT_VALUE
                        );
                        // Decrement the trait by the trait value.
                        let _new_trait_value = current_trait_value - trait_value;
                    // IERC7496(token).setTrait(identifier, traitRedemptions[i].traitKey, bytes32(newTraitValue));
                    } else if substandard == 4 {
                        // Revert if the current trait value is not equal to the trait value.
                        assert(
                            current_trait_value == substandard_value,
                            Errors::INVALID_REQUIRED_TRAIT_VALUE
                        );
                    // No-op: substandard 4 has no set trait action.
                    }
                    i += 1;
                }
        }
    }
}
