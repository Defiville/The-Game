//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "./library/token/ERC1155/ERC1155Holder.sol";
import "./library/token/ERC1155/IERC1155.sol";
import "./library/token/ERC20/SafeERC20.sol";

contract VendingMachine is ERC1155Holder {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct Sale {
        address creator;
        address nft;
        uint256 tokenId;
        uint256 amountLeft;
        address tokenWant;
        uint256 pricePerUnit;
    }

    bytes4 private constant _INTERFACE_ID_ERC1155 = 0xd9b67a26;
    
    mapping (uint256 => Sale) public sales;
    uint256 newSaleId;

    event NewSale(
        address indexed creator, 
        address indexed nft, 
        uint256 tokenId, 
        uint256 amount, 
        address tokenWant, 
        uint256 pricePerUnit,
        uint256 saleId
    );
    event BuyNFT(address buyer, uint256 saleId, uint256 amountLeft);
    event CancelSale(address creator, uint256 saleId, uint256 amountNotSold);
    event ChangePricePerUnit(uint256 saleId, uint256 pricePerUnit);
    event ChangeTokenWant(uint256 saleId, address tokenWant);
    event ChangeTokenWantAndPrice(uint256 saleId, address tokenWant, uint256 pricePerUnit);

    /**
     * @dev Function for creating a new ERC1155 NFT sale using ETH as payment system
     * @param erc1155 erc1155 nft address related to tokenIds
     * @param tokenIds nft ids to sell
     * @param amounts nft ids amounts to sell
     * @param pricesPerUnit price in wei for each unit for each token id
     */
    function createNFTSaleForETH(
        address erc1155,
        uint256[] memory tokenIds,
        uint256[] memory amounts,
        uint256[] memory pricesPerUnit
    ) external payable {
        // set address(0) for ETH as tokenWant
        _createERC1155Sale(erc1155, tokenIds, amounts, address(0), pricesPerUnit);   
    }

    /**
     * @dev External function for creating a new ERC1155 NFT sale using ERC20 as payment system
     * @param erc1155 nft address to sell
     * @param tokenIds nft id to sell
     * @param amounts nft id amount to sell
     * @param tokenWant token want address 
     * @param pricesPerUnit price in tokenWant 
     */
    function createNFTSaleForERC20(
        address erc1155, 
        uint256[] memory tokenIds, 
        uint256[] memory amounts, 
        address tokenWant, 
        uint256[] memory pricesPerUnit
    ) external {
        _createERC1155Sale(erc1155, tokenIds, amounts, tokenWant, pricesPerUnit);
    }

    /**
     * @dev Internal function for creating a new ERC1155 NFT sale
     * @param erc1155 nft address to sell
     * @param tokenIds nft id to sell
     * @param amounts nft id amount to sell
     * @param tokenWant token want address 
     * @param pricesPerUnit price per unit
     */
    function _createERC1155Sale(
        address erc1155, 
        uint256[] memory tokenIds, 
        uint256[] memory amounts, 
        address tokenWant, 
        uint256[] memory pricesPerUnit
    ) 
        internal 
    {        
        require(IERC165(erc1155).supportsInterface(_INTERFACE_ID_ERC1155));
        IERC1155 nft = IERC1155(erc1155);
        if (tokenIds.length == 1) {
            nft.safeTransferFrom(msg.sender, address(this), tokenIds[0], amounts[0], '');
        } else {
            nft.safeBatchTransferFrom(msg.sender, address(this), tokenIds, amounts, '');
        }
        for (uint256 i = 0; i < tokenIds.length; i++) {
            Sale memory newSale = Sale(msg.sender, erc1155, tokenIds[i], amounts[i], tokenWant, pricesPerUnit[i]);
            sales[newSaleId] = newSale;
            emit NewSale(msg.sender, erc1155, tokenIds[i], amounts[i], tokenWant, pricesPerUnit[i], newSaleId);
            newSaleId = newSaleId + 1;
        }
    }

    /**
     * @dev Function for changing the price per NFT unit in a sale
     * @param saleId nft sale id
     * @param pricePerUnit price per unit to change
     */
    function changePricePerUnit(uint256 saleId, uint256 pricePerUnit) external {
        Sale storage sale = sales[saleId];
        require(sale.creator == msg.sender);
        sale.pricePerUnit = pricePerUnit;
        emit ChangePricePerUnit(saleId, pricePerUnit);
    }

    /**
     * @dev Funtion for changing the token want and price per NFT unit in a sale
     * @param saleId nft sale id
     * @param tokenWant new token want address
     * @param pricePerUnit price per unit to change
     */
    function changeTokenWantAndPrice(uint256 saleId, address tokenWant, uint256 pricePerUnit) external {
        Sale storage sale = sales[saleId];
        require(sale.creator == msg.sender);
        sale.tokenWant = tokenWant;
        sale.pricePerUnit = pricePerUnit;
        emit ChangeTokenWantAndPrice(saleId, tokenWant, pricePerUnit);
    } 

    /**
     * @dev Buy one or more of the same NFT id in a sale
     * @param saleId nft sale id
     * @param amount amount of tokenId to buy in saleId
     */
    function buyNFT(uint256 saleId, uint256 amount) external payable {
        Sale storage sale = sales[saleId];
        require(sale.amountLeft >= amount, 'Sale amount exceed');
        IERC20 tokenWant = IERC20(sale.tokenWant);
        uint256 tokenTotalAmount = amount.mul(sale.pricePerUnit);
        require (tokenTotalAmount <= tokenWant.balanceOf(msg.sender), 'Balance of token want too low');
        tokenWant.safeTransferFrom(msg.sender, sale.creator, tokenTotalAmount);
        IERC1155 nft = IERC1155(sale.nft);
        nft.safeTransferFrom(address(this), msg.sender, sale.tokenId, amount, '');
        sale.amountLeft = sale.amountLeft.sub(amount);
        emit BuyNFT(msg.sender, saleId, sale.amountLeft);
    }

    /**
     * @dev Cancel a NFT sale, it transfers all NFT left to sale creator
     * @param saleId sale to delete
     */
    function cancelSale(uint256 saleId) external {
        Sale memory sale = sales[saleId];
        require(sale.creator == msg.sender);
        IERC1155 nft = IERC1155(sale.nft);
        nft.safeTransferFrom(address(this), msg.sender, sale.tokenId, sale.amountLeft, '');
        delete sales[saleId];
        emit CancelSale(msg.sender, saleId, sale.amountLeft);
    }
}