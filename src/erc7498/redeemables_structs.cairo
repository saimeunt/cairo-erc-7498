use starknet::ContractAddress;
use cairo_erc_7498::utils::consideration_structs::{OfferItem, ConsiderationItem};

#[derive(Copy, PartialEq, Drop, Serde, starknet::Store)]
pub struct TraitRedemption {
    pub substandard: u8,
    pub token: ContractAddress,
    pub trait_key: felt252,
    pub trait_value: felt252,
    pub substandard_value: felt252,
}

#[derive(Copy, PartialEq, Drop, Serde)]
pub struct CampaignRequirements {
    pub offer: Span<OfferItem>,
    pub consideration: Span<ConsiderationItem>,
    pub trait_redemptions: Span<TraitRedemption>,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct CampaignRequirementsStorage {
    pub offer_len: u32,
    pub consideration_len: u32,
    pub trait_redemptions_len: u32,
}

#[derive(Copy, PartialEq, Drop, Serde, starknet::Store)]
pub struct CampaignParams {
    pub start_time: u64,
    pub end_time: u64,
    pub max_campaign_redemptions: u32,
    pub manager: ContractAddress,
    pub signer: ContractAddress,
}

#[derive(Copy, PartialEq, Drop, Serde)]
pub struct Campaign {
    pub params: CampaignParams,
    pub requirements: Span<CampaignRequirements>,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct CampaignStorage {
    pub params: CampaignParams,
    pub requirements_len: u32,
}
