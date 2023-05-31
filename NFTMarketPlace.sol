// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title NFTMarketPlace
 * @dev A decentralized marketplace for buying and selling ERC721 tokens (NFTs).
 */
contract NFTMarketPlace is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsSold;

    uint256 listingPrice = 0.00025 ether;

    mapping(uint256 => MarketItem) private idMarketItem;

    struct MarketItem {
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool isSold;
    }

    event idMarketItemCreated(
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool isSold
    );

    /**
     * @dev Initializes the NFTMarketPlace contract.
     */
    constructor() ERC721("NFT", "MyNFT") {}

    /**
     * @dev Updates the listing price for creating a market item.
     * @param _listingPrice The new listing price.
     */
    function updateListingPrice(uint256 _listingPrice) public payable onlyOwner {
        listingPrice = _listingPrice;
    }

    /**
     * @dev Gets the current listing price for creating a market item.
     * @return The current listing price.
     */
    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    /**
     * @dev Creates a new ERC721 token and lists it for sale in the marketplace.
     * @param tokenURI The URI for the token's metadata.
     * @param price The price of the token.
     * @return The ID of the newly created token.
     */
    function createToken(string memory tokenURI, uint256 price)
        public
        payable
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newTokenId = _tokenIds.current();

        _mint(msg.sender, newTokenId);

        _setTokenURI(newTokenId, tokenURI);

        createMarketItem(newTokenId, price);

        return newTokenId;
    }

    /**
     * @dev Creates a market item for a given token.
     * @param _tokenId The ID of the token.
     * @param _price The price of the token.
     */
    function createMarketItem(uint256 _tokenId, uint256 _price) private {
        require(_price >= 1, "Price must be at least 1");
        require(
            msg.value == listingPrice,
            "Price must be equal to the listing price"
        );
        idMarketItem[_tokenId] = MarketItem(
            _tokenId,
            payable(msg.sender),
            payable(address(this)),
            _price,
            false
        );
        _transfer(msg.sender, address(this), _tokenId);

        emit idMarketItemCreated(
            _tokenId,
            msg.sender,
            address(this),
            _price,
            false
        );
    }

    /**
     * @dev Allows the token owner to re-list a token for sale.
     * @param tokenId The ID of the token.
     * @param price The new price of the token.
     */
    function reSellToken(uint256 tokenId, uint256 price) public payable {
        require(
            idMarketItem[tokenId].owner == msg.sender,
            "Only item owner can perform this operation."
        );
        require(
            msg.value == listingPrice,
            "Price must be equal to the listing price"
        );

        idMarketItem[tokenId].isSold = false;
        idMarketItem[tokenId].price = price;
        idMarketItem[tokenId].seller = payable(msg.sender);
        idMarketItem[tokenId].owner = payable(address(this));
        _itemsSold.decrement();

        _transfer(msg.sender, address(this), tokenId);
    }

    /**
     * @dev Executes the sale of a token and transfers ownership to the buyer.
     * @param tokenId The ID of the token.
     */
    function createMarketSale(uint256 tokenId) public payable {
        uint256 price = idMarketItem[tokenId].price;

        require(msg.value == price, "Please submit the asked price");
        idMarketItem[tokenId].owner = payable(msg.sender);
        idMarketItem[tokenId].isSold = true;
        idMarketItem[tokenId].seller = payable(address(0));

        _itemsSold.increment();

        _transfer(address(this), msg.sender, tokenId);

        payable(owner()).transfer(listingPrice);
        payable(idMarketItem[tokenId].seller).transfer(msg.value);
    }

    /**
     * @dev Fetches the unsold market items.
     * @return An array of MarketItem representing the unsold market items.
     */
    function fetchMarketItem() public view returns (MarketItem[] memory) {
        uint256 itemCount = _tokenIds.current();
        uint256 unSoldItemCount = itemCount - _itemsSold.current();
        uint256 currentIndex;

        MarketItem[] memory items = new MarketItem[](unSoldItemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (idMarketItem[i + 1].owner == address(this)) {
                items[currentIndex] = idMarketItem[i + 1];
                currentIndex += 1;
            }
        }
        return items;
    }

    /**
     * @dev Fetches the market items owned by the caller.
     * @return An array of MarketItem representing the caller's market items.
     */
    function fetchMyNFT() public view returns (MarketItem[] memory) {
        uint256 totalCount = _tokenIds.current();
        uint256 itemCount = 0;

        for (uint256 i = 0; i < totalCount; i++) {
            if (idMarketItem[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalCount; i++) {
            if (idMarketItem[i + 1].owner == msg.sender) {
                items[currentIndex] = idMarketItem[i + 1];
                currentIndex += 1;
            }
        }

        return items;
    }

    /**
     * @dev Fetches the market items listed by the caller.
     * @return An array of MarketItem representing the caller's listed market items.
     */
    function fetchItemsListed() public view returns (MarketItem[] memory) {
        uint256 totalCount = _tokenIds.current();
        uint256 itemCount = 0;

        for (uint256 i = 0; i < totalCount; i++) {
            if (idMarketItem[i + 1].seller == msg.sender) {
                itemCount += 1;
            }
        }
        MarketItem[] memory items = new MarketItem[](itemCount);
        uint256 currentIndex = 0;

        for (uint256 i = 1; i <= totalCount; i++) {
            if (idMarketItem[i + 1].seller == msg.sender) {
                items[currentIndex] = idMarketItem[i + 1];
                currentIndex += 1;
            }
        }
        return items;
    }
}
