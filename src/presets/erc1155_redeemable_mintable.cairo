use starknet::ContractAddress;
use cairo_erc_7498::utils::consideration_structs::{OfferItem, ConsiderationItem};
use cairo_erc_7498::erc7498::redeemables_structs::{Campaign, TraitRedemption};

#[starknet::interface]
pub trait IERC1155RedeemableMintable<TState> {
    fn mint(ref self: TState, to: ContractAddress, token_id: u256, value: u256);
    fn burn(ref self: TState, from: ContractAddress, token_id: u256, value: u256);
    fn batch_burn(
        ref self: TState, from: ContractAddress, token_ids: Span<u256>, values: Span<u256>
    );
    fn create_campaign(ref self: TState, campaign: Campaign, uri: ByteArray) -> u256;
    fn mint_redemption(
        ref self: TState,
        campaign_id: u256,
        recipient: ContractAddress,
        offer: OfferItem,
        consideration: Span<ConsiderationItem>,
        trait_redemptions: Span<TraitRedemption>
    );
    fn get_redeemables_contracts(self: @TState) -> Span<ContractAddress>;
    fn set_redeemables_contracts(ref self: TState, redeemables_contracts: Span<ContractAddress>);
}

#[starknet::interface]
pub trait IERC1155RedeemableMintableMixin<TState> {
    // IERC1155Redeemable
    fn mint(ref self: TState, to: ContractAddress, token_id: u256, value: u256);
    fn get_redeemables_contracts(self: @TState) -> Span<ContractAddress>;
    fn set_redeemables_contracts(ref self: TState, redeemables_contracts: Span<ContractAddress>);
    // IERC1155Burnable
    fn burn(ref self: TState, from: ContractAddress, token_id: u256, value: u256);
    fn batch_burn(
        ref self: TState, from: ContractAddress, token_ids: Span<u256>, values: Span<u256>
    );
    // IERC7498
    fn get_campaign(self: @TState, campaign_id: u256) -> (Campaign, ByteArray, u256);
    fn create_campaign(ref self: TState, campaign: Campaign, uri: ByteArray) -> u256;
    fn update_campaign(ref self: TState, campaign_id: u256, campaign: Campaign, uri: ByteArray);
    fn redeem(
        ref self: TState,
        consideration_token_ids: Span<u256>,
        recipient: ContractAddress,
        extra_data: Span<felt252>
    );
    // IERC1155
    fn balance_of(self: @TState, account: ContractAddress, token_id: u256) -> u256;
    fn balance_of_batch(
        self: @TState, accounts: Span<ContractAddress>, token_ids: Span<u256>
    ) -> Span<u256>;
    fn safe_transfer_from(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        value: u256,
        data: Span<felt252>
    );
    fn safe_batch_transfer_from(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        token_ids: Span<u256>,
        values: Span<u256>,
        data: Span<felt252>
    );
    fn is_approved_for_all(
        self: @TState, owner: ContractAddress, operator: ContractAddress
    ) -> bool;
    fn set_approval_for_all(ref self: TState, operator: ContractAddress, approved: bool);
    // ERC1155Receiver
    fn on_erc1155_received(
        self: @TState,
        operator: ContractAddress,
        from: ContractAddress,
        token_id: u256,
        value: u256,
        data: Span<felt252>
    ) -> felt252;
    fn on_erc1155_batch_received(
        self: @TState,
        operator: ContractAddress,
        from: ContractAddress,
        token_ids: Span<u256>,
        values: Span<u256>,
        data: Span<felt252>
    ) -> felt252;
    // Ownable
    fn owner(self: @TState) -> ContractAddress;
    fn transfer_ownership(ref self: TState, new_owner: ContractAddress);
    fn renounce_ownership(ref self: TState);
    // ISRC5
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;
}

#[starknet::contract]
pub mod ERC1155RedeemableMintable {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use openzeppelin::introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc1155::{ERC1155Component, ERC1155HooksEmptyImpl};
    use openzeppelin::token::erc1155::ERC1155ReceiverComponent;
    use alexandria_storage::list::{List, ListTrait};
    use cairo_erc_7498::erc7498::interface::IREDEMPTION_MINTABLE_ID;
    use cairo_erc_7498::utils::consideration_structs::{OfferItem, ConsiderationItem};
    use cairo_erc_7498::erc7498::erc7498::ERC7498Component;
    use cairo_erc_7498::erc7498::redeemables_errors::Errors;
    use cairo_erc_7498::erc7498::redeemables_structs::{Campaign, TraitRedemption};

    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: ERC1155Component, storage: erc1155, event: ERC1155Event);
    component!(
        path: ERC1155ReceiverComponent, storage: erc1155_receiver, event: ERC1155ReceiverEvent
    );
    component!(path: ERC7498Component, storage: erc7498, event: ERC7498Event);

    // Ownable
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // ERC1155Mixin
    #[abi(embed_v0)]
    impl ERC1155MixinImpl = ERC1155Component::ERC1155MixinImpl<ContractState>;
    impl ERC1155InternalImpl = ERC1155Component::InternalImpl<ContractState>;

    // IERC1155Receiver
    #[abi(embed_v0)]
    impl ERC1155ReceiverImpl =
        ERC1155ReceiverComponent::ERC1155ReceiverImpl<ContractState>;
    impl ERC1155ReceiverInternalImpl = ERC1155ReceiverComponent::InternalImpl<ContractState>;

    // ERC7498
    #[abi(embed_v0)]
    impl ERC7498Impl = ERC7498Component::ERC7498Impl<ContractState>;
    impl ERC7498InternalImpl = ERC7498Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        erc1155: ERC1155Component::Storage,
        #[substorage(v0)]
        erc1155_receiver: ERC1155ReceiverComponent::Storage,
        #[substorage(v0)]
        erc7498: ERC7498Component::Storage,
        /// @dev The ERC-7498 redeemables contracts.
        erc7498_redeemables_contracts: List<ContractAddress>,
        /// @dev The next token id to mint.
        next_token_id: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ERC1155Event: ERC1155Component::Event,
        #[flat]
        ERC1155ReceiverEvent: ERC1155ReceiverComponent::Event,
        #[flat]
        ERC7498Event: ERC7498Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, base_uri: ByteArray) {
        self.ownable.initializer(get_caller_address());
        self.src5.register_interface(IREDEMPTION_MINTABLE_ID);
        self.erc1155.initializer(base_uri);
        self.erc1155_receiver.initializer();
        self.erc7498.initializer();
    }

    #[abi(embed_v0)]
    impl ERC1155RedeemableImpl of super::IERC1155RedeemableMintable<ContractState> {
        fn mint(ref self: ContractState, to: ContractAddress, token_id: u256, value: u256) {
            self.ownable.assert_only_owner();
            self.erc1155.mint_with_acceptance_check(to, token_id, value, array![].span());
        }

        fn burn(ref self: ContractState, from: ContractAddress, token_id: u256, value: u256) {
            let operator = get_caller_address();
            if from != operator {
                assert(
                    self.erc1155.is_approved_for_all(from, operator),
                    ERC1155Component::Errors::UNAUTHORIZED
                );
            }
            self.erc1155.burn(from, token_id, value);
        }

        fn batch_burn(
            ref self: ContractState,
            from: ContractAddress,
            token_ids: Span<u256>,
            values: Span<u256>
        ) {
            let operator = get_caller_address();
            if from != operator {
                assert(
                    self.erc1155.is_approved_for_all(from, operator),
                    ERC1155Component::Errors::UNAUTHORIZED
                );
            }
            self.erc1155.batch_burn(from, token_ids, values);
        }

        fn create_campaign(ref self: ContractState, campaign: Campaign, uri: ByteArray) -> u256 {
            self.ownable.assert_only_owner();
            self.erc7498._create_campaign(@campaign, uri)
        }

        fn mint_redemption(
            ref self: ContractState,
            campaign_id: u256,
            recipient: ContractAddress,
            offer: OfferItem,
            consideration: Span<ConsiderationItem>,
            trait_redemptions: Span<TraitRedemption>
        ) {
            // Require that msg.sender is valid.
            self._require_valid_redeemables_caller();
            // Increment nextTokenId first so more of the same token id cannot be minted through reentrancy.
            let next_token_id = self.next_token_id.read();
            self.next_token_id.write(next_token_id + 1);
            self.erc1155.mint_with_acceptance_check(recipient, next_token_id, 1, array![].span());
        }

        fn get_redeemables_contracts(self: @ContractState) -> Span<ContractAddress> {
            let redeemables_contracts_list = self.erc7498_redeemables_contracts.read();
            let redeemables_contracts_array = redeemables_contracts_list.array().unwrap();
            redeemables_contracts_array.span()
        }

        fn set_redeemables_contracts(
            ref self: ContractState, redeemables_contracts: Span<ContractAddress>
        ) {
            self.ownable.assert_only_owner();
            let mut redeemables_contracts_list = self.erc7498_redeemables_contracts.read();
            let mut i = 0;
            while !redeemables_contracts_list
                .is_empty() {
                    let _must_use = redeemables_contracts_list.pop_front();
                    i += 1;
                };
            i = 0;
            while i < redeemables_contracts
                .len() {
                    let _must_use = redeemables_contracts_list.append(*redeemables_contracts[i]);
                    i += 1;
                }
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _require_valid_redeemables_caller(self: @ContractState) {
            // Allow the contract to call itself.
            if get_caller_address() == get_contract_address() {
                return;
            }
            let mut valid_caller = false;
            let redeemables_contracts_list = self.erc7498_redeemables_contracts.read();
            let redeemables_contracts_array = redeemables_contracts_list.array().unwrap();
            let mut i = 0;
            while i < redeemables_contracts_array
                .len() {
                    if get_caller_address() == *redeemables_contracts_array[i] {
                        valid_caller = false;
                    }
                };
            assert(valid_caller, Errors::INVALID_CALLER);
        }
    }
}
