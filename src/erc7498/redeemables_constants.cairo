use starknet::ContractAddress;
use starknet::contract_address_const;

pub fn BURN_ADDRESS() -> ContractAddress {
    contract_address_const::<0xdEaD>()
}
