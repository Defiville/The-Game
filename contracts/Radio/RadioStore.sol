//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "../Common/library/math/SafeMath.sol";
import "../Common/library/Ownable.sol";
import "../Common/library/token/ERC20/SafeERC20.sol";
import "../Common/library/token/ERC1155/ERC1155Holder.sol";


contract Track {

}

// 

// fee system -> for every sell
contract RadioStore is Ownable, ERC1155Holder {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address tokenWantA;
    IERC20 tokenWant;

    uint256 ONE_18 = 10 ** 18;
    uint256 fee = 2 * ONE_18;

    bytes4 private constant _INTERFACE_ID_ERC1155 = 0xd9b67a26;
    bytes4 private constant _INTERFACE_ID_ERC721 = 0xd9b67a26; // to edit

    struct SaleUnique {
        address ERC721;
        uint256 tokenId;
        uint256 price;
    }

    struct Sale {
        address ERC1155;
        uint256 tokenId;
        uint256 amount;
        uint256 pricePerUnit;
    }

    mapping (uint256 => SaleUnique) salesUnique;
    mapping (uint256 => Sale) sales; 
    mapping (address => bool) wlArtists;

    uint256 nextSaleId;
    uint256 nextSaleUniqueId;

    event NewSale(address nft, uint256 amount, uint256 pricePerUnit);
    event NewSaleUnique(address nft, uint256 price);

    constructor() {

    }

    // Sell ERC721 track
    // ERC721 nft token address
    // ERC721 nft
    function sellUniqueTrack(address _nft, uint256 _tokenId, uint256 _price) external {
        require(IERC165(_nft).supportsInterface(_INTERFACE_ID_ERC721));
        _sellUniqueTrack(_nft, _tokenId, _price);
    }

    // Sell ERC721 track in batch
    function sellUniqueTrackInBatch(
        address[] memory _nftsA,
        uint256[] memory _tokenIds, 
        uint256[] memory _prices
    ) external {
        require(_nftsA.length == _prices.length);
        for (uint256 i = 0; i < _nftsA.length ; i ++) {
            _sellUniqueTrack(_nftsA[i], _tokenIds[i], _prices[i]);
        } 
    }

    function _sellUniqueTrack(address _nft, uint256 _tokenId, uint256 _price) internal {
        SaleUnique memory sale = SaleUnique(_nft, _tokenId, _price);
        salesUnique[nextSaleUniqueId] = sale;
        nextSaleUniqueId = nextSaleUniqueId + 1;
        emit NewSaleUnique(_nft, _price); 
    }

    // Sell ERC1155 track with amount
    function sellTrack(address _nft, uint256 _tokenId, uint256 _amount, uint256 _pricePerUnit) external {
        // check if the nft address is erc1155 compliant
        require(IERC165(_nft).supportsInterface(_INTERFACE_ID_ERC1155));
        _sellTrack(_nft, _tokenId, _amount, _pricePerUnit);
    }

    // Sell ERC1155 track in batch
    function sellTrackInBatch(
        address[] memory _nfts,
        uint256[] memory _tokenIds,
        uint256[] memory _amounts,
        uint256[] memory _pricesPerUnit
    ) external {
        require((_nfts.length == _amounts.length) && (_amounts.length == _pricesPerUnit.length), 'd');
        for (uint256 i = 0; i < _nfts.length; i++) {
            _sellTrack(_nfts[i], _tokenIds[i], _amounts[i], _pricesPerUnit[i]);
        }
    }

    function _sellTrack(address _nft, uint256 _tokenId, uint256 _amount, uint256 _pricePerUnit) internal {
        Sale memory sale = Sale(_nft, _tokenId, _amount, _pricePerUnit);
        sales[nextSaleId] = sale;
        nextSaleId = nextSaleId + 1;
        emit NewSale(_nft, _amount, _pricePerUnit);
    }

    function sellTrackInVanillaCurve(
        address _nft, 
        uint256 _tokenId,
        uint256 _exponentParameter,
        uint256 _slopeParameter
    ) external {

    }

    function buyUniqueTrack(uint256 _saleId) external {
        SaleUnique memory sale = salesUnique[_saleId];
        require(sale.ERC721 != address(0));
        require(tokenWant.balanceOf(msg.sender) >= sale.price);
        //IERC721(sale.ERC721).transfer(msg.sender, '');
    }

    function buyTrack(uint256 _saleId, uint256 _amount) external {
        Sale memory sale = sales[_saleId];
        uint256 totalAmount = sale.pricePerUnit.mul(_amount);
        require(sale.ERC1155 != address(0));
        require(tokenWant.balanceOf(msg.sender) >= totalAmount);
        tokenWant.transferFrom(msg.sender, address(this), totalAmount);
    }

    function addArtist(address _artist) external onlyOwner {
        require(!wlArtists[_artist]);
        wlArtists[_artist] = true;
    }

    function tipArtist(address _artist, address[] memory _tokens, uint256[] memory _amounts) external {
        require(_tokens.length == _amounts.length, 'Different length');
        require(wlArtists[_artist]);
        for (uint256 i = 0; i < _tokens.length; i++) {
            IERC20(_tokens[i]).transfer(_artist, _amounts[i]);
        }
    }

    function tipArtists(address[] memory _artists, address _token, uint256[] memory _amounts) external {
        require(_artists.length == _amounts.length, 'Different length');
        for (uint256 i = 0; i < _artists.length; i++) {
            require(wlArtists[_artists[i]]);
            IERC20(_token).transfer(_artists[i], _amounts[i]);
        }
    }
}