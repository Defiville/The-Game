//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import "../Common/library/math/SafeMath.sol";
import "../Common/library/token/ERC20/SafeERC20.sol";
import "../Common/library/Ownable.sol";

contract RadioTips is Ownable {
    
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct Artist {
        string name;
        address recipient;
        mapping (address => uint256) tipsJar;
    }

    // it will be used for any blockchain native currency (ETH-xDAI)
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    mapping (address => uint256) public radioJars;
    mapping (uint256 => Artist) public artists;
    mapping (uint256 => address) public artistRecipients;   
    uint256 public nextArtistId;
    uint256 tipInETH;
    
    event AddArtist(string name, address recipient, uint256 artistId);
    event RedeemRadioTips(address recipient, address[] tokens, uint256[] amounts);
    event RedeemArtistTips(uint256 indexed artistId, address[] tokens, uint256[] amounts);
    event SetArtistRecipient(uint256 artistId, address newRecipient);
    event TipRadio(address indexed user, address indexed token, uint256 amount);
    event TipArtist(
        address indexed user, 
        address indexed token, 
        uint256 indexed artistId, 
        uint256 amount
    );

    /**
     * @dev Function for tipping defiville radio service
     * @param _token token used for tipping the radio
     * @param _amount amount to tip
     */
    function tipRadio(address _token, uint256 _amount) external payable {
        _tipRadio(_token, _amount);
        _checkTipInEth();
    }
    
    /**
     * @dev Function for tipping defiville radio service with multiple tokens
     * @param _tokens tokens used for tipping the radio
     * @param _amounts amounts to tip
     */
    function tipsRadio(address[] memory _tokens, uint256[] memory _amounts) external payable {
        require(_tokens.length == _amounts.length, 'Different length');
        for (uint256 i = 0; i < _tokens.length; i++) {
            _tipRadio(_tokens[i], _amounts[i]);
        }
        _checkTipInEth();
    }

    /**
     * @dev Internal function for tipping the service
     * @param _token token used for tipping the radio
     * @param _amount amount to tip
     */
    function _tipRadio(address _token, uint256 _amount) internal {
        if (_token == ETH) {
            tipInETH = tipInETH.add(_amount);
        } else {
            _receiveToken(_token, _amount);
        }
        radioJars[_token] = radioJars[_token].add(_amount);
        emit TipRadio(msg.sender, _token, _amount); 
    }
    
    /**
     * @dev Function for tipping an artist
     * @param _artistId artist id
     * @param _token token used for tipping the artist
     * @param _amount amount to tip 
     */
    function tipArtist(uint256 _artistId, address _token, uint256 _amount) external payable {
        _tipArtist(_artistId, _token, _amount);
        _checkTipInEth();
    }

    /**
     * @dev Function for tipping more than one artist
     * @param _artistIds erc1155 nft address related to tokenIds
     * @param _tokens nft ids to sell
     * @param _amounts nft ids amounts to sell
     * @notice Also it could be used to tip the same artist but with more than one token
     */
    function tipArtists(
        uint256[] memory _artistIds,
        address[] memory _tokens,
        uint256[] memory _amounts
    ) external payable {
        require(_artistIds.length == _amounts.length, 'Different length');
        for (uint256 i = 0; i < _artistIds.length; i++) {
            _tipArtist(_artistIds[i], _tokens[i], _amounts[i]);
        }
        _checkTipInEth();
    }

    /**
     * @dev Internal function for tipping more than one artist
     * @param _artistId artist id to tip
     * @param _token token used for tipping
     * @param _amount token amount
     */
    function _tipArtist(uint256 _artistId, address _token, uint256 _amount) internal {
        require(_artistId < nextArtistId, 'Artist id not created yet');
        Artist storage artist = artists[_artistId];
        if (_token == ETH) {
            tipInETH = tipInETH.add(_amount);
        } else {
            _receiveToken(_token, _amount);
        }
        artist.tipsJar[_token] = artist.tipsJar[_token].add(_amount);
        emit TipArtist(msg.sender, _token, _artistId, _amount); 
    }

    /**
     * @dev Internal function for checking the correctness related 
     * to the native blockchain currency amount sent as tip (ETH/xDAI)
     */
    function _checkTipInEth() internal {
        require(tipInETH == msg.value, 'Wrong amount');
        if (tipInETH > 0) {
            tipInETH = 0;
        }
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
     * @param _names artists name
     */
    function addArtists(string[] memory _names) external onlyOwner {
        for (uint256 i = 0; i < _names.length; i++) {
          _addArtist(_names[i], address(0));  
        }
    }

    /**
     * @dev Function to add a new artist with recipient
     * @param _names artists name
     * @param _recipients artists recepient
     */
    function addArtistsWithRecipient(string[] memory _names, address[] memory _recipients) external onlyOwner {
        for (uint256 i = 0; i < _names.length; i++) {
           _addArtist(_names[i], _recipients[i]); 
        }
    }

    /**
     * @dev Internal function to add a new artist
     * @param _name artist name
     * @param _recipient artist recepient
     */
    function _addArtist(string memory _name, address _recipient) internal {
        Artist storage artist = artists[nextArtistId];
        require(keccak256(abi.encodePacked(_name)) != keccak256(abi.encodePacked('')), 'Empty Name');
        artist.name = _name;
        if (_recipient != address(0)) {
           artist.recipient = _recipient;
           artistRecipients[nextArtistId] = _recipient;
        }
        emit AddArtist(_name, _recipient, nextArtistId);
        nextArtistId = nextArtistId + 1;
    }
    
    /**
     * @dev Function to redeem artist tips
     * @param _artistId artist id
     * @param _tokens tokens to redeem
     * @param _amounts amount for each token
     */
    function redeemArtistTips(
        uint256 _artistId,
        address[] memory _tokens,
        uint256[] memory _amounts
    ) external {
        Artist storage artist = artists[_artistId];
        uint256 ethToSend;
        require(msg.sender == artist.recipient, 'Only recipient');
        require(_tokens.length == _amounts.length, 'Different length');
        for (uint256 i = 0; i < _tokens.length; i++) {
            require(artist.tipsJar[_tokens[i]] >= _amounts[i], 'Amount exceed tips');
            if (_tokens[i] == ETH) {
                ethToSend = ethToSend.add(_amounts[i]);
            } else {
                _sendToken(_tokens[i], artist.recipient, _amounts[i]);
            }        
            artist.tipsJar[_tokens[i]] = artist.tipsJar[_tokens[i]].sub(_amounts[i]);  
        }
        if (ethToSend > 0) {
            payable(artist.recipient).transfer(ethToSend); 
        }
        emit RedeemArtistTips(_artistId, _tokens, _amounts);
    }
    
    /**
     * @dev Function to redeem radio tips
     * @param _tokens tokens to redeem
     * @param _amounts amounts for each token
     * @param _recipient recipient to send radio tips
     */
    function redeemRadioTips(
        address[] memory _tokens,
        uint256[] memory _amounts,
        address _recipient
    ) external onlyOwner {
        uint256 ethToSend;
        require(_tokens.length == _amounts.length, 'Different length');
        for (uint256 i = 0; i < _tokens.length; i++) {
            require(radioJars[_tokens[i]] >= _amounts[i], 'Amount exceed tips');
            if (_tokens[i] == ETH) {
                ethToSend = ethToSend.add(_amounts[i]);
            } else {
                _sendToken(_tokens[i], _recipient, _amounts[i]);
            }
           radioJars[_tokens[i]] = radioJars[_tokens[i]].sub(_amounts[i]);
        }
        if (ethToSend > 0) {
            payable(_recipient).transfer(ethToSend);
        }
        emit RedeemRadioTips(_recipient, _tokens, _amounts);
    }

    /**
     * @dev Internal function to send token to outside
     * @param _token token to send
     * @param _recipient recipient to send token
     * @param _amount amount to send
     */
    function _sendToken(address _token, address _recipient, uint256 _amount) internal {
        uint256 balanceBefore = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(_recipient, _amount);
        uint256 balanceAfter = IERC20(_token).balanceOf(address(this));
        require(balanceBefore.sub(balanceAfter) == _amount, 'Incorrect amount sent'); 
    }

    /**
     * @dev Function to initialize artist recipient
     * @param _artistId artist id
     * @param _recipient artist recipient
     * @notice It could be called at most once per artist by the owner
     */
    function initializeArtistRecipient(uint256 _artistId, address _recipient) external onlyOwner {
        require(artistRecipients[_artistId] == address(0), 'Already initialized');
        _setRecipient(_artistId, _recipient);
    }

    /**
     * @dev Function to set a new artist recipient
     * @param _artistId artist id
     * @param _recipient artist address
     * @notice It could be called only by the artist recipient address
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

    /**
     * @dev Function to retrieve artists tip amount
     * @param _artistId artist id
     * @param _token token to check
     */
    function getArtistTip(uint256 _artistId, address _token) external view returns(uint256) {
        Artist storage artist = artists[_artistId];
        return artist.tipsJar[_token];
    }
}