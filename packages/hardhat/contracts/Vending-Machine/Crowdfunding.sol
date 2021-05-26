//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "./library/token/ERC1155/ERC1155Base.sol";
import "./library/math/SafeMath.sol";
import "./library/token/ERC20/SafeERC20.sol";

contract Crowdfunding is ERC1155Base {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct Campaign {
        address creator;
        address tokenWant;
        string metadataURI;
        uint256 amountRaised;
    }

    struct Product {
        uint256 campaignId;
        uint256 tokenId;
        uint256 amount;
        uint256 pricePerUnit;
        string metadataURI;
    }

    string public name;
    string public symbol;

    mapping (uint256 => Campaign) public campaigns;
    mapping (uint256 => Product) public products;
    uint256 public nextCampaignId;
    uint256 public nextTokenId;

    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    event CreateCampaing(address creator, address tokenWant, string uri);
    event AddProduct(uint256 campaignId, uint256 productId, uint256 amount, uint256 pricePerUnit);
    event BuyProduct(uint256 productId, uint256 campaignId, uint256 amount, uint256 totalAmount);

    constructor() {
        name = "Defiville Crowdfunding";
        symbol = "DVCF";
    }

    function newCampaign(address _tokenWant) external {
        _createCampaign(_tokenWant, '');
    }

    function newCampaign(address _tokenWant, string memory _metadataURI) external {
        _createCampaign(_tokenWant, _metadataURI);
    }

    function _createCampaign(address _tokenWant, string memory _metadataURI) internal {
        Campaign memory campaign = Campaign(msg.sender, _tokenWant, _metadataURI, 0);
        campaigns[nextCampaignId] = campaign;
        nextCampaignId++;

        emit CreateCampaing(msg.sender, _tokenWant, _metadataURI);
    }

    function addProduct(uint256 _campaignId, uint256 _amount, uint256 _pricePerUnit) external {
        _addProduct(_campaignId, _amount, _pricePerUnit, '');
    }

    function addProduct(
        uint256 _campaignId, 
        uint256 _amount, 
        uint256 _pricePerUnit, 
        string memory _metadataURI) 
        external {
            _addProduct(_campaignId, _amount, _pricePerUnit, _metadataURI);
    }

    function _addProduct(
        uint256 _campaignId, 
        uint256 _amount, 
        uint256 _pricePerUnit, 
        string memory _metadataURI
    ) internal {
        Campaign memory campaign = campaigns[_campaignId];
        require(campaign.creator == msg.sender);
        Product memory product = Product(_campaignId, nextTokenId, _amount, _pricePerUnit, _metadataURI);
        products[nextTokenId] = product;
        _mintProduct(nextTokenId, _amount, _metadataURI);
        nextTokenId++;
    }

    function _mintProduct(uint256 _id, uint256 _supply, string memory _uri) internal {
        _mint(_id, _supply, _uri);
    }

    function buyProduct(uint256 _campaignId, uint256 _productId, uint256 _amount) payable external {
        Campaign memory campaign = campaigns[_campaignId];
        Product memory product = products[_productId];
        uint256 totalPrice = product.pricePerUnit.mul(_amount);
        if (campaign.tokenWant == NATIVE) {
            require(totalPrice == msg.value);
            payable(campaign.creator).transfer(totalPrice); 
        } else {
            _sendtoken(campaign.tokenWant, totalPrice, campaign.creator);
        }
    }

    function _sendtoken(address _token, uint256 _amount, address _creator) internal {
        uint256 amountBefore = IERC20(_token).balanceOf(_creator);
        IERC20(_token).transferFrom(msg.sender, _creator, _amount);
        uint256 amountAfter = IERC20(_token).balanceOf(_creator);
        require(amountAfter.sub(amountBefore) == _amount, 'Wrong amount sent');
    }

    function changeProductPrice(uint256 _campaignId, uint256 _productId, uint256 _pricePerUnit) external {
        Campaign memory campaign = campaigns[_campaignId];
        require(campaign.creator == msg.sender);
        Product storage product = products[_productId];
        require(product.campaignId == _campaignId);
        product.pricePerUnit = _pricePerUnit;
    }
}