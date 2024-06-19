use starknet::ContractAddress;
use cairo_erc_7498::utils::consideration_structs::{OfferItem, ConsiderationItem};
use cairo_erc_7498::erc7498::redeemables_structs::{TraitRedemption, Campaign};

pub const IERC7498_ID: felt252 = 0x1ac61e13;

#[starknet::interface]
pub trait IERC7498<TState> {
    fn get_campaign(self: @TState, campaign_id: u256) -> (Campaign, ByteArray, u256);
    fn update_campaign(ref self: TState, campaign_id: u256, campaign: Campaign, uri: ByteArray);
    fn redeem(
        ref self: TState,
        consideration_token_ids: Span<u256>,
        recipient: ContractAddress,
        extra_data: Span<felt252>
    );
}

#[starknet::interface]
pub trait IERC7498Mixin<TState> {
    fn get_campaign(self: @TState, campaign_id: u256) -> (Campaign, ByteArray, u256);
    fn create_campaign(ref self: TState, campaign: Campaign, uri: ByteArray) -> u256;
    fn update_campaign(ref self: TState, campaign_id: u256, campaign: Campaign, uri: ByteArray);
    fn redeem(
        ref self: TState,
        consideration_token_ids: Span<u256>,
        recipient: ContractAddress,
        extra_data: Span<felt252>
    );
}

pub const IREDEMPTION_MINTABLE_ID: felt252 = 0x81fe13c2;

#[starknet::interface]
pub trait IRedemptionMintable<TState> {
    fn mint_redemption(
        ref self: TState,
        campaign_id: u256,
        recipient: ContractAddress,
        offer: OfferItem,
        consideration: Span<ConsiderationItem>,
        trait_redemptions: Span<TraitRedemption>
    );
}

#[starknet::interface]
pub trait IERC721Burnable<TState> {
    fn burn(ref self: TState, token_id: u256);
}

#[starknet::interface]
pub trait IERC1155Burnable<TState> {
    fn burn(ref self: TState, from: ContractAddress, token_id: u256, value: u256);
    fn batch_burn(
        ref self: TState, from: ContractAddress, token_ids: Span<u256>, values: Span<u256>
    );
}

#[starknet::interface]
pub trait IERC20Burnable<TState> {
    fn burn(ref self: TState, account: ContractAddress, amount: u256);
}
