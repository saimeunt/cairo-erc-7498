use starknet::ContractAddress;
use cairo_erc_7498::erc7498::redeemables_structs::Campaign;

#[starknet::interface]
pub trait IERC1155Redeemable<TState> {
    fn mint(ref self: TState, to: ContractAddress, token_id: u256, value: u256);
    fn burn(ref self: TState, from: ContractAddress, token_id: u256, value: u256);
    fn batch_burn(
        ref self: TState, from: ContractAddress, token_ids: Span<u256>, values: Span<u256>
    );
    fn create_campaign(ref self: TState, campaign: Campaign, uri: ByteArray) -> u256;
}

#[starknet::interface]
pub trait IERC1155RedeemableMixin<TState> {
    // IERC1155Redeemable
    fn mint(ref self: TState, to: ContractAddress, token_id: u256, value: u256);
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
pub mod ERC1155Redeemable {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc1155::{ERC1155Component, ERC1155HooksEmptyImpl};
    use openzeppelin::token::erc1155::ERC1155ReceiverComponent;
    use cairo_erc_7498::erc7498::erc7498::ERC7498Component;
    use cairo_erc_7498::erc7498::redeemables_structs::Campaign;

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
        self.erc1155.initializer(base_uri);
        self.erc1155_receiver.initializer();
        self.erc7498.initializer();
    }

    #[abi(embed_v0)]
    impl ERC1155RedeemableImpl of super::IERC1155Redeemable<ContractState> {
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
    }
}
