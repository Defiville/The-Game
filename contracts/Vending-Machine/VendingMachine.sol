//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "./library/token/ERC1155/ERC1155Holder.sol";
import "./library/token/ERC1155/IERC1155.sol";
import "./library/token/ERC20/SafeERC20.sol";

/*
Simple smart contract for creating ERC1155 sales.
Users can create a new NFT sale, it supports both ETH and ERC20 as a payment system,
but in this version each sale allows to define only one payment token per time.
The sale creator can modify the tokenWant (ERC20 or ETH) and the price per tokenId unit.
ERC721 is not supported in this version.
*/
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
    event BuyNFT(address indexed buyer, uint256 saleId, uint256 amount);
    event CancelSale(address indexed creator, uint256 saleId, uint256 amountReturned);
    event ChangePricePerUnit(uint256 indexed saleId, uint256 pricePerUnit);
    event ChangeTokenWantAndPrice(uint256 indexed saleId, address tokenWant, uint256 pricePerUnit);

    /**
     * @dev Function for creating a new ERC1155 NFT sale using ETH as payment system
     * @param erc1155 erc1155 nft address related to tokenIds
     * @param tokenId nft ids to sell
     * @param amount nft ids amounts to sell
     * @param pricePerUnit price in wei for each unit
     */
    function createNFTSaleForETH(
        address erc1155,
        uint256 tokenId,
        uint256 amount,
        uint256 pricePerUnit
    ) external {
        // set address(0) for ETH as tokenWant
        _createERC1155Sale(erc1155, tokenId, amount, address(0), pricePerUnit);   
    }

    /**
     * @dev Function for creating a new ERC1155 NFT sale using ERC20 as payment system
     * @param erc1155 nft address to sell
     * @param tokenId nft id to sell
     * @param amount nft id amount to sell
     * @param tokenWant token want address 
     * @param pricePerUnit price in tokenWant, with decimals 
     */
    function createNFTSaleForERC20(
        address erc1155, 
        uint256 tokenId, 
        uint256 amount, 
        address tokenWant, 
        uint256 pricePerUnit
    ) external {
        _createERC1155Sale(erc1155, tokenId, amount, tokenWant, pricePerUnit);
    }

    /**
     * @dev Internal function for creating a new ERC1155 NFT sale
     * @param _erc1155 nft address to sell
     * @param _tokenId nft tokenId to sell
     * @param _amount nft tokenId amount to sell
     * @param _tokenWant token want address, address(0) for ETH
     * @param _pricePerUnit price per unit
     */
    function _createERC1155Sale(
        address _erc1155, 
        uint256 _tokenId, 
        uint256 _amount, 
        address _tokenWant, 
        uint256 _pricePerUnit
    ) 
        internal 
    {   
        // check if the nft address is erc1155 compliant
        require(IERC165(_erc1155).supportsInterface(_INTERFACE_ID_ERC1155));
        
        // check if amount transfered is correct
        _sendNFTToVending(_erc1155, _tokenId, _amount);
        
        // create new sale 
        Sale memory newSale = Sale(msg.sender, _erc1155, _tokenId, _amount, _tokenWant, _pricePerUnit);
        sales[newSaleId] = newSale;
        emit NewSale(msg.sender, _erc1155, _tokenId, _amount, _tokenWant, _pricePerUnit, newSaleId);
        newSaleId = newSaleId + 1;
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
     * @dev Funtion for changing the token want and price per NFT unit in a sale already opened
     * @param saleId nft sale id
     * @param tokenWant new token want address
     * @param pricePerUnit new price per unit, with decimals
     */
    function changeTokenWantAndPrice(uint256 saleId, address tokenWant, uint256 pricePerUnit) external {
        Sale storage sale = sales[saleId];
        require(sale.creator == msg.sender);
        sale.tokenWant = tokenWant;
        sale.pricePerUnit = pricePerUnit;
        emit ChangeTokenWantAndPrice(saleId, tokenWant, pricePerUnit);
    } 

    /**
     * @dev Function for buying one or more of the same NFT id in a sale
     * @param saleId nft sale id
     * @param amount amount of tokenId to buy in saleId 
     */
    function buyNFT(uint256 saleId, uint256 amount) external payable {
        Sale storage sale = sales[saleId];
        require(sale.amountLeft >= amount, 'Sale amount exceed');
        uint256 tokenTotalAmount = amount.mul(sale.pricePerUnit);
        
        // sale in ERC20
        if (sale.tokenWant != address(0)) {
            IERC20 tokenWant = IERC20(sale.tokenWant);
            require (tokenTotalAmount <= tokenWant.balanceOf(msg.sender), 'Balance of token want too low');
            tokenWant.safeTransferFrom(msg.sender, sale.creator, tokenTotalAmount);
        } else {
            require(msg.value  == tokenTotalAmount, 'Sent wrong amount of ETH');
            payable(sale.creator).transfer(msg.value);
        }
        
        // transfer nft to buyer
        _sendNFT(sale.nft, sale.tokenId, amount);
        sale.amountLeft = sale.amountLeft.sub(amount);
        emit BuyNFT(msg.sender, saleId, sale.amountLeft);
    }

    /**
     * @dev Internal function for sending tokenId amount to buyer
     * @param _nft address of erc1155 nft
     * @param _tokenId erc1155 nft tokenId
     * @param _amount amount to send
     */
    function _sendNFT(address _nft, uint256 _tokenId, uint256 _amount) internal {
       IERC1155 nft = IERC1155(_nft);
       uint256 amountBefore = nft.balanceOf(address(this), _tokenId);
       nft.safeTransferFrom(address(this), msg.sender, _tokenId, _amount, '');
       uint256 amountAfter =  nft.balanceOf(address(this), _tokenId);
       require(amountAfter.add(_amount) == amountBefore, 'Wrong nft amount sent');
    }

    /**
     * @dev Internal function for sending tokenId amount to vending
     * @param _nft address of erc1155 nft
     * @param _tokenId erc1155 nft tokenId
     * @param _amount amount to send
     */
    function _sendNFTToVending(address _nft, uint256 _tokenId, uint256 _amount) internal {
        IERC1155 nft = IERC1155(_nft);
        uint256 amountBefore = nft.balanceOf(address(this), _tokenId);
        nft.safeTransferFrom(msg.sender, address(this), _tokenId, _amount, '');
        uint256 amountAfter = nft.balanceOf(address(this), _tokenId);
        require (amountAfter.sub(amountBefore) == _amount, 'Wrong nft amount received');
    }

    /**
     * @dev Cancel a NFT sale, it transfers all amount left to sale creator
     * @param saleId to delete
     */
    function cancelSale(uint256 saleId) external {
        Sale memory sale = sales[saleId];
        require(sale.creator == msg.sender);
        require(sale.amountLeft > 0, 'Nothing left');

        // transfer amount left to sale creator and delete sales data
        _sendNFT(sale.nft, sale.tokenId, sale.amountLeft);
        delete sales[saleId];
        emit CancelSale(msg.sender, saleId, sale.amountLeft);
    }
}