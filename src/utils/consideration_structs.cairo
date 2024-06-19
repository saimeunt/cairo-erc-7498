use starknet::ContractAddress;
use starknet::contract_address_const;
use cairo_erc_7498::utils::consideration_enums::ItemType;

// @dev An offer item has five components: an item type (ETH or other native
//      tokens, ERC20, ERC721, and ERC1155, as well as criteria-based ERC721 and
//      ERC1155), a token address, a dual-purpose "identifierOrCriteria"
//      component that will either represent a tokenId or a merkle root
//      depending on the item type, and a start and end amount that support
//      increasing or decreasing amounts over the duration of the respective
//      order.
#[derive(Copy, PartialEq, Drop, Serde, starknet::Store)]
pub struct OfferItem {
    pub item_type: ItemType,
    pub token: ContractAddress,
    pub identifier_or_criteria: u256,
    pub start_amount: u256,
    pub end_amount: u256,
}

#[generate_trait]
pub impl OfferItemImpl of OfferItemTrait {
    fn empty() -> OfferItem {
        OfferItem {
            item_type: ItemType::NATIVE,
            token: contract_address_const::<0>(),
            identifier_or_criteria: 0,
            start_amount: 0,
            end_amount: 0,
        }
    }
    fn with_item_type(self: @OfferItem, item_type: ItemType) -> OfferItem {
        OfferItem {
            item_type,
            token: *self.token,
            identifier_or_criteria: *self.identifier_or_criteria,
            start_amount: *self.start_amount,
            end_amount: *self.end_amount,
        }
    }
    fn with_token(self: @OfferItem, token: ContractAddress) -> OfferItem {
        OfferItem {
            item_type: *self.item_type,
            token,
            identifier_or_criteria: *self.identifier_or_criteria,
            start_amount: *self.start_amount,
            end_amount: *self.end_amount,
        }
    }
    fn with_identifier_or_criteria(self: @OfferItem, identifier_or_criteria: u256) -> OfferItem {
        OfferItem {
            item_type: *self.item_type,
            token: *self.token,
            identifier_or_criteria,
            start_amount: *self.start_amount,
            end_amount: *self.end_amount,
        }
    }
    fn with_start_amount(self: @OfferItem, start_amount: u256) -> OfferItem {
        OfferItem {
            item_type: *self.item_type,
            token: *self.token,
            identifier_or_criteria: *self.identifier_or_criteria,
            start_amount,
            end_amount: *self.end_amount,
        }
    }
    fn with_end_amount(self: @OfferItem, end_amount: u256) -> OfferItem {
        OfferItem {
            item_type: *self.item_type,
            token: *self.token,
            identifier_or_criteria: *self.identifier_or_criteria,
            start_amount: *self.start_amount,
            end_amount,
        }
    }
    fn with_amount(self: @OfferItem, amount: u256) -> OfferItem {
        OfferItem {
            item_type: *self.item_type,
            token: *self.token,
            identifier_or_criteria: *self.identifier_or_criteria,
            start_amount: amount,
            end_amount: amount,
        }
    }
}

// @dev A consideration item has the same five components as an offer item and
//      an additional sixth component designating the required recipient of the
//      item.
#[derive(Copy, PartialEq, Drop, Serde, starknet::Store)]
pub struct ConsiderationItem {
    pub item_type: ItemType,
    pub token: ContractAddress,
    pub identifier_or_criteria: u256,
    pub start_amount: u256,
    pub end_amount: u256,
    pub recipient: ContractAddress
}

#[generate_trait]
pub impl ConsiderationItemImpl of ConsiderationItemTrait {
    fn empty() -> ConsiderationItem {
        ConsiderationItem {
            item_type: ItemType::NATIVE,
            token: contract_address_const::<0>(),
            identifier_or_criteria: 0,
            start_amount: 0,
            end_amount: 0,
            recipient: contract_address_const::<0>(),
        }
    }
    fn with_item_type(self: @ConsiderationItem, item_type: ItemType) -> ConsiderationItem {
        ConsiderationItem {
            item_type,
            token: *self.token,
            identifier_or_criteria: *self.identifier_or_criteria,
            start_amount: *self.start_amount,
            end_amount: *self.end_amount,
            recipient: *self.recipient,
        }
    }
    fn with_token(self: @ConsiderationItem, token: ContractAddress) -> ConsiderationItem {
        ConsiderationItem {
            item_type: *self.item_type,
            token,
            identifier_or_criteria: *self.identifier_or_criteria,
            start_amount: *self.start_amount,
            end_amount: *self.end_amount,
            recipient: *self.recipient,
        }
    }
    fn with_identifier_or_criteria(
        self: @ConsiderationItem, identifier_or_criteria: u256
    ) -> ConsiderationItem {
        ConsiderationItem {
            item_type: *self.item_type,
            token: *self.token,
            identifier_or_criteria,
            start_amount: *self.start_amount,
            end_amount: *self.end_amount,
            recipient: *self.recipient,
        }
    }
    fn with_start_amount(self: @ConsiderationItem, start_amount: u256) -> ConsiderationItem {
        ConsiderationItem {
            item_type: *self.item_type,
            token: *self.token,
            identifier_or_criteria: *self.identifier_or_criteria,
            start_amount,
            end_amount: *self.end_amount,
            recipient: *self.recipient,
        }
    }
    fn with_end_amount(self: @ConsiderationItem, end_amount: u256) -> ConsiderationItem {
        ConsiderationItem {
            item_type: *self.item_type,
            token: *self.token,
            identifier_or_criteria: *self.identifier_or_criteria,
            start_amount: *self.start_amount,
            end_amount,
            recipient: *self.recipient,
        }
    }
    fn with_amount(self: @ConsiderationItem, amount: u256) -> ConsiderationItem {
        ConsiderationItem {
            item_type: *self.item_type,
            token: *self.token,
            identifier_or_criteria: *self.identifier_or_criteria,
            start_amount: amount,
            end_amount: amount,
            recipient: *self.recipient,
        }
    }
    fn with_recipient(self: @ConsiderationItem, recipient: ContractAddress) -> ConsiderationItem {
        ConsiderationItem {
            item_type: *self.item_type,
            token: *self.token,
            identifier_or_criteria: *self.identifier_or_criteria,
            start_amount: *self.start_amount,
            end_amount: *self.end_amount,
            recipient,
        }
    }
}
