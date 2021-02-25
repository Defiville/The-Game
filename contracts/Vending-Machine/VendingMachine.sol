//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "./library/token/ERC1155/ERC1155Holder.sol";
import "./library/security/Pausable.sol";
import "./library/token/ERC1155/IERC1155.sol";
import "./library/token/ERC721/IERC721.sol";
import "./library/token/ERC20/SafeERC20.sol";
import "./library/token/ERC721/ERC721Holder.sol";

contract VendingMachine is Pausable, ERC1155Holder, ERC721Holder {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct Sale {
        address creator;
        address nftAddress;
        uint256 tokenId;
        uint256 amount;
        address tokenWant;
        uint256 pricePerUnit;
        bytes4 nftInterface;
    }

    bytes4 private constant _INTERFACE_ID_ERC1155 = 0xd9b67a26;
    bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;
    
    mapping (uint256 => Sale) public sales;
    uint256 newSalesId;

    event ERC1155Sale(
        address creator, 
        address nft, 
        uint256 tokenId, 
        uint256 amount, 
        address tokenWant, 
        uint256 pricePerUnit,
        uint256 saleId
    );

    event ERC721Sale(
        address creator, 
        address nft, 
        uint256 tokenId, 
        address tokenWant, 
        uint256 pricePerUnit,
        uint256 saleId
    );

    event BuyNFT(address buyer, uint256 saleId);
    event CancelSale(address creator, uint256 saleId);
    event ChangePricePerUnit(uint256 saleId, uint256 pricePerUnit);
    event ChangeTokenWant(uint256 saleId, address tokenWant);
    event ChangeTokenWantAndPrice(uint256 saleId, address tokenWant, uint256 pricePerUnit);

    modifier onlySaleCreator(uint256 saleId) {
        Sale memory sale = sales[saleId];
        require(sale.creator == msg.sender);
        _;
    }

    function erc721Sale(address erc721, uint256 tokenId, address tokenWant, uint256 pricePerUnit) external {
        require(IERC165(erc721).supportsInterface(_INTERFACE_ID_ERC721));
        IERC721 nft = IERC721(erc721);
        nft.transferFrom(msg.sender, address(this), tokenId);
        Sale memory newSale = Sale(msg.sender, erc721, tokenId, 1, tokenWant, pricePerUnit, _INTERFACE_ID_ERC721);
        _newNFTSale(newSale);
    }

    function erc1155Sale(address erc1155, uint256 tokenId, uint256 amount, address tokenWant, uint256 pricePerUnit) external {
        require(IERC165(erc1155).supportsInterface(_INTERFACE_ID_ERC1155));
        IERC1155 nft = IERC1155(erc1155);
        nft.safeTransferFrom(msg.sender, address(this), tokenId, amount, '');
        Sale memory newSale = Sale(msg.sender, erc1155, tokenId, amount, tokenWant, pricePerUnit, _INTERFACE_ID_ERC1155);
        _newNFTSale(newSale);
    }

    function _newNFTSale(Sale memory newSale) 
        internal 
    {        
        sales[newSalesId] = newSale;
        newSalesId++;
    }

    function changePricePerUnit(uint256 saleId, uint256 pricePerUnit) external onlySaleCreator(saleId) {
        Sale storage saleToEdit = sales[saleId];
        saleToEdit.pricePerUnit = pricePerUnit;
        emit ChangePricePerUnit(saleId, pricePerUnit);
    }

    function changeTokenWant(uint256 saleId, address tokenWant) external onlySaleCreator(saleId) {
        Sale storage saleToEdit = sales[saleId];
        saleToEdit.tokenWant = tokenWant;
        emit ChangeTokenWant(saleId, tokenWant);
    }

    function changeTokenWantAndPrice(uint256 saleId, address tokenWant, uint256 pricePerUnit) external onlySaleCreator(saleId) {
        Sale storage saleToEdit = sales[saleId];
        saleToEdit.tokenWant = tokenWant;
        saleToEdit.pricePerUnit = pricePerUnit;
        emit ChangeTokenWantAndPrice(saleId, tokenWant, pricePerUnit);
    } 

    function buyNFT(uint256 saleId, uint256 amount) external payable {
        Sale storage sale = sales[saleId];
        require(sale.amount >= amount, 'Sale amount exceed');
        IERC20 tokenWant = IERC20(sale.tokenWant);
        uint256 tokenTotalAmount = amount.mul(sale.pricePerUnit);
        require (tokenTotalAmount <= tokenWant.balanceOf(msg.sender), 'Balance of token want too low');
        tokenWant.safeTransferFrom(msg.sender, sale.creator, tokenTotalAmount);
        if (sale.nftInterface == _INTERFACE_ID_ERC721) {
            IERC721 nft = IERC721(sale.nftAddress);
            nft.safeTransferFrom(address(this), msg.sender, sale.tokenId);
            delete sales[saleId];
        } else if (sale.nftInterface == _INTERFACE_ID_ERC1155) {
            IERC1155 nft = IERC1155(sale.nftAddress);
            nft.safeTransferFrom(address(this), msg.sender, sale.tokenId, amount, '');
            sale.amount = sale.amount.sub(amount);
        }
    }


    function cancelSale(uint256 saleId) external onlySaleCreator(saleId) {
        Sale memory sale = sales[saleId];

        if (sale.nftInterface == _INTERFACE_ID_ERC721) {
            IERC721 nft = IERC721(sale.nftAddress);
            nft.safeTransferFrom(address(this), msg.sender, sale.tokenId);
        } else if (sale.nftInterface == _INTERFACE_ID_ERC1155) {
            IERC1155 nft = IERC1155(sale.nftAddress);
            nft.safeTransferFrom(address(this), msg.sender, sale.tokenId, sale.amount, '');
        }
        delete sales[saleId];
        emit CancelSale(msg.sender, saleId);
    }
}