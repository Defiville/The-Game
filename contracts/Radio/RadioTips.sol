//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "../Common/library/math/SafeMath.sol";
import "../Common/library/token/ERC20/SafeERC20.sol";
import "../Common/library/Ownable.sol";

contract RadioTips is Ownable {
    
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct Artist {
        bytes32 name;
        address recipient;
        mapping (address => uint256) tipJars;
    }

    mapping (address => uint256) public radioJars;
    mapping (uint256 => Artist) public artists;
    mapping (uint256 => address) public artistRecipients;
    uint256 public nextArtistId;
    
    event AddArtist(bytes32 name, address recipient);
    event RedeemRadioTips(address recipient, address[] tokens, uint256[] amounts);
    event RedeemArtistTips(uint256 indexed artistId, address[] tokens, uint256[] amounts);
    event SetArtistRecipient(uint256 artistId, address newRecipient);
    event TipRadio(address indexed user, address token, uint256 amount);
    event TipArtist(
        address indexed user, 
        address indexed token, 
        uint256 indexed artistId, 
        uint256 amount
    );
    
    /**
     * @dev Function for tipping radio service
     * @param _token token used for tipping the radio
     * @param _amount amount to tip
     */
    function tipRadio(address _token, uint256 _amount) external {
        _receiveToken(_token, _amount);
        radioJars[_token] = radioJars[_token].add(_amount);
        emit TipRadio(msg.sender, _token, _amount);
    }
    
    /**
     * @dev Function for tipping an artist
     * @param _artistId artist id
     * @param _token token used for tipping the artist
     * @param _amount amount to tip 
     */
    function tipArtist(uint256 _artistId, address _token, uint256 _amount) external {
        _tipArtist(_artistId, _token, _amount);
    }

    /**
     * @dev Function for tipping more than one artist
     * @param _artistIds erc1155 nft address related to tokenIds
     * @param _tokens nft ids to sell
     * @param _amounts nft ids amounts to sell
     * @notice It could be used to tip the same artist but with more than one token
     */
    function tipArtists(
        uint256[] memory _artistIds,
        address[] memory _tokens,
        uint256[] memory _amounts
    ) external {
        require(_artistIds.length == _amounts.length, 'Different length');
        for (uint256 i = 0; i < _artistIds.length; i++) {
            _tipArtist(_artistIds[i], _tokens[i], _amounts[i]);
        }
    }

    /**
     * @dev Internal function for tipping more than one artist
     * @param _artistId artist id to tip
     * @param _token token used for tipping
     * @param _amount token amount
     */
    function _tipArtist(uint256 _artistId, address _token, uint256 _amount) internal {
        require(_artistId < nextArtistId, 'Artist id not minted yet');
        Artist storage artist = artists[_artistId];
        //require(keccak256(abi.encodePacked(artist.name)) != keccak256(abi.encodePacked('')), 'No Name');
        _receiveToken(_token, _amount);
        artist.tipJars[_token] = artist.tipJars[_token].add(_amount);
        emit TipArtist(msg.sender, _token, _artistId, _amount); 
    }
    
    /**
     * @dev Internal function to receive the token from outside
     * @param _token token to receive
     * @param _amount amount to receive
     */
    function _receiveToken(address _token, uint256 _amount) internal {
        IERC20 token = IERC20(_token);
        uint256 balanceBefore = token.balanceOf(address(this));
        token.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 balanceAfter = token.balanceOf(address(this));
        require(balanceAfter == balanceBefore.add(_amount), 'Incorrect amount received');
    }
    
    /**
     * @dev Function to add a new artist
     * @param _names artist names
     */
    function addArtists(bytes32[] memory _names) external onlyOwner {
        for (uint256 i = 0; i < _names.length; i++) {
          _addArtist(_names[i], address(0));  
        }
    }

    /**
     * @dev Function to add a new artist
     * @param _names artist names
     * @param _recipients artist recepients
     */
    function addArtistsWithRecipient(bytes32[] memory _names, address[] memory _recipients) external onlyOwner {
        for (uint256 i = 0; i < _names.length; i++) {
           _addArtist(_names[i], _recipients[i]); 
        }
    }

    /**
     * @dev Internal function to add a new artist
     * @param _name artist name
     * @param _recipient artist recepient
     */
    function _addArtist(bytes32 _name, address _recipient) internal {
        Artist storage artist = artists[nextArtistId];
        artist.name = _name;
        if (_recipient != address(0)) {
           artist.recipient = _recipient;
           artistRecipients[nextArtistId] = _recipient;
        }
        nextArtistId = nextArtistId + 1;
        emit AddArtist(_name, _recipient);
    }
    
    /**
     * @dev Function to add a new artist
     * @param _artistId artist name
     * @param _tokens artist recepient
     * @param _amounts artist recepient
     */
    function redeemArtistTips(
        uint256 _artistId,
        address[] memory _tokens,
        uint256[] memory _amounts
    ) external {
        Artist storage artist = artists[_artistId];
        require(msg.sender == artist.recipient, 'Only recipient');
        require(_tokens.length == _amounts.length, 'Different length');
        for (uint256 i = 0; i < _tokens.length; i++) {
          require(artist.tipJars[_tokens[i]] >= _amounts[i], 'Amount exceed tips');    
          _sendToken(_tokens[i], artist.recipient, _amounts[i]);
          artist.tipJars[_tokens[i]] = artist.tipJars[_tokens[i]].sub(_amounts[i]);  
        }
        emit RedeemArtistTips(_artistId, _tokens, _amounts);
    }
    
    /**
     * @dev Function to add a new artist
     * @param _tokens artist name
     * @param _recipient artist recepient
     * @param _amounts artist recepient
     */
    function redeemRadioTips(
        address[] memory _tokens,
        address _recipient,
        uint256[] memory _amounts
    ) external onlyOwner {
        require(_tokens.length == _amounts.length, 'Differen length');
        for (uint256 i = 0; i < _tokens.length; i++) {
           _sendToken(_tokens[i], _recipient, _amounts[i]);
           require(radioJars[_tokens[i]] >= _amounts[i], 'Amount exceed tips');
           radioJars[_tokens[i]] = radioJars[_tokens[i]].sub(_amounts[i]);
        }
        emit RedeemRadioTips(_recipient, _tokens, _amounts);
    }

    /**
     * @dev Internal function to send token to contract
     * @param _token artist name
     * @param _recipient artist recepient
     * @param _amount artist recepient
     */
    function _sendToken(address _token, address _recipient, uint256 _amount) internal {
        uint256 balanceBefore = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(_recipient, _amount);
        uint256 balanceAfter = IERC20(_token).balanceOf(address(this));
        require(balanceBefore.sub(balanceAfter) == _amount, 'Incorrect amount sent'); 
    }

    /**
     * @dev Function to initialize artist recipient
     * @param _artistId artist name
     * @param _recipient artist recepient
     * @notice It could be called at most once per artist
     */
    function initializeArtistRecipient(uint256 _artistId, address _recipient) external onlyOwner {
        require(artistRecipients[_artistId] == address(0), 'Already initialized');
        _setRecipient(_artistId, _recipient);
    }

    /**
     * @dev Function to set a new artist recipient
     * @param _artistId artist id
     * @param _recipient artist address
     */
    function setArtistRecipient(uint256 _artistId, address _recipient) external {
        require(msg.sender == artistRecipients[_artistId], '!Recipient');
        _setRecipient(_artistId, _recipient);
    }

    /**
     * @dev Internal function to set a new artist recipient
     * @param _artistId artist id
     * @param _recipient artist address
     */
    function _setRecipient(uint256 _artistId, address _recipient) internal {
        require(_recipient != address(0), 'No address 0x');
        Artist storage artist = artists[_artistId];
        artist.recipient = _recipient;
        artistRecipients[_artistId] = _recipient;
        emit SetArtistRecipient(_artistId, _recipient);
    }
}