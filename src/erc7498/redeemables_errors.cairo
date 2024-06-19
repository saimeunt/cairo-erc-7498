pub mod Errors {
    /// Configuration errors
    pub const NOT_MANAGER: felt252 = 'ERC7498: not manager';
    pub const INVALID_TIME: felt252 = 'ERC7498: invalid time';
    pub const CONSIDERATION_ITEM_RECIPIENT_CANNOT_BE_ZERO_ADDRESS: felt252 =
        'ERC7498: CIR cannot be 0';
    pub const CONSIDERATION_ITEM_AMOUNT_CANNOT_BE_ZERO: felt252 = 'ERC7498: CIA cannot be 0';
    pub const NON_MATCHING_CONSIDERATION_ITEM_AMOUNTS: felt252 = 'ERC7498: non matching CIA';
    /// Redemption errors
    pub const INVALID_CAMPAIGN_ID: felt252 = 'ERC7498: invalid campaign id';
    pub const INVALID_CALLER: felt252 = 'ERC7498: invalid caller';
    pub const NOT_ACTIVE: felt252 = 'ERC7498: not active';
    pub const MAX_CAMPAIGN_REDEMPTIONS_REACHED: felt252 = 'ERC7498: max redemptions reach';
    pub const REQUIREMENTS_INDEX_OUT_OF_BOUNDS: felt252 = 'ERC7498: requirements index OOB';
    pub const CONSIDERATION_ITEM_INSUFFICIENT_BALANCE: felt252 = 'ERC7498: CI insufficient bal';
    pub const INVALID_CONSIDERATION_TOKEN_ID_SUPPLIED: felt252 = 'ERC7498: invalid CTI';
    pub const TOKEN_IDS_DONT_MATCH_CONSIDERATION_LENGTH: felt252 = 'ERC7498: token ids mismatch';
    pub const TRAIT_REDEMPTION_TOKEN_IDS_DONT_MATCH_TRAIT_REDEMPTIONS_LENGTH: felt252 =
        'ERC7498: traits mismatch';
    pub const INVALID_REQUIRED_TRAIT_VALUE: felt252 = 'ERC7498: Invalid trait value';
}
