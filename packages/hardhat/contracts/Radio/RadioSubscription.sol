//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "../Common/library/math/SafeMath.sol";
import "../Common/library/token/ERC20/SafeERC20.sol";
import "../Common/library/Ownable.sol";

contract RadioSubscription is Ownable {
    
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    uint256 ONE_18 = 10 ** 18;
    address public tokenWantA;
    IERC20 tokenWant; // xDAI
    mapping (address => uint256) public subscribers;
    mapping (address => bool) public wlArtists;
    mapping (address => uint256) public artistsShare;
    uint256 public monthlyPrice = 5 * ONE_18; // 5 xDAI per month
    uint256 monthSeconds = 2592000; // 1 Month
    uint256 public artistsJar;
    uint256 public radioJar;
    uint256 public percentageForArtists = 50;
    
    event AddArtist(address[] artist);
    event Earn(address recipient, address token, uint256 amount);
    event RedeemArtistShare(address indexed artist, uint256 amount);
    event SetArtistsPercentage(uint256 oldPercentage, uint256 newPercentage);
    event SetMonthlyPrice(uint256 oldPrice, uint256 newPrice);
    event Subscribe(address indexed user, uint256 months);
    event TipRadio(address indexed user, address token, uint256 amount);
    event TipArtist(
        address indexed user, 
        address indexed token, 
        address indexed artist, 
        uint256 amount
    );
    event TipArtists(address indexed user, uint256 amount);
    
    
    constructor() {
    }
    
    function subscribe(uint256 _months) external {
        uint256 totalAmount = monthlyPrice * _months;
        
        _receiveToken(tokenWantA, totalAmount);
        
        artistsJar = artistsJar.add(totalAmount.div(100).mul(percentageForArtists));
        radioJar = radioJar.add(totalAmount.sub(artistsJar));
        require(radioJar.add(artistsJar) == totalAmount);
        
        uint256 secondsToAdd = _months.mul(monthSeconds);
        if (subscribers[msg.sender] == 0) {
            subscribers[msg.sender] = block.timestamp.add(secondsToAdd);
        } else {
            subscribers[msg.sender] = subscribers[msg.sender].add(secondsToAdd);
        }
        emit Subscribe(msg.sender, _months);
    }
    
    function tipRadio(address _token, uint256 _amount) external {
        _receiveToken(_token, _amount);
        if (_token == tokenWantA) {
            radioJar = radioJar.add(_amount);
        }
        emit TipRadio(msg.sender, _token, _amount);
    }
    
    function tipArtist(address _artist, address _token, uint256 _amount) external {
        require(wlArtists[_artist]);
        IERC20(_token).transferFrom(msg.sender, _artist, _amount);
        emit TipArtist(msg.sender, _token, _artist, _amount);
    }

    function tipArtists(uint256 _amount) external {
        _receiveToken(tokenWantA, _amount);
        artistsJar = artistsJar.add(_amount);
        emit TipArtists(msg.sender, _amount);
    }
    
    function _receiveToken(address _token, uint256 _amount) internal {
        IERC20 token = IERC20(_token);
        uint256 balanceBefore = token.balanceOf(address(this));
        token.transferFrom(msg.sender, address(this), _amount);
        uint256 balanceAfter = token.balanceOf(address(this));
        require(balanceAfter == balanceBefore.add(_amount));
    }
    
    function addArtists(address[] memory _artists) external onlyOwner {
        for (uint256 i = 0; i < _artists.length; i++) {
           require(wlArtists[_artists[i]] == false);
            wlArtists[_artists[i]] = true; 
        }
        emit AddArtist(_artists);
    }
    
    function reserveForArtists(address[] memory _artists, uint256[] memory _amounts) external onlyOwner {
        require(_artists.length == _amounts.length, 'Different length');
        
        uint256 totalAmount;
        for (uint256 j = 0; j < _artists.length; j++) {
            totalAmount = totalAmount.add(_amounts[j]);
        }
        require(totalAmount <= artistsJar, 'Amount exceed Jar');
        
        for (uint256 i = 0; i < _artists.length; i++) {
            artistsShare[_artists[i]] = artistsShare[_artists[i]].add(_amounts[i]);
        }
        artistsJar = artistsJar.sub(totalAmount);
    }
    
    function redeemArtistShare(uint256 _amount) external {
        require(wlArtists[msg.sender], 'Not in Whitelist');
        require(artistsShare[msg.sender] > _amount, 'Amount exceed shares');
        _sendToken(tokenWantA, msg.sender, _amount);
        artistsShare[msg.sender] = artistsShare[msg.sender].sub(_amount);
        emit RedeemArtistShare(msg.sender, _amount);
    }
    
    function earn(address _token, address _recipient, uint256 _amount) external onlyOwner {
        if (_token == tokenWantA) {
            require(_amount <= radioJar);
            radioJar = radioJar.sub(_amount);
        }
        _sendToken(_token, _recipient, _amount);
        emit Earn(_recipient, _token, _amount);
    }

    function _sendToken(address _token, address _recipient, uint256 _amount) internal {
        uint256 balanceBefore = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(_recipient, _amount);
        uint256 balanceAfter = IERC20(_token).balanceOf(address(this));
        require(balanceBefore.sub(balanceAfter) == _amount); 
    }

    function setArtistsPercentage(uint256 _newPercentage) external onlyOwner {
        require(_newPercentage <= 100);
        emit SetArtistsPercentage(percentageForArtists, _newPercentage);
        percentageForArtists = _newPercentage;
    }

    function setMonthlyPrice(uint256 _newPrice) external onlyOwner {
        require(_newPrice >= ONE_18); // at least 1 xDAI
        emit SetMonthlyPrice(monthlyPrice, _newPrice);
        monthlyPrice = _newPrice;
    }
    
    function isSubscribed(address _user) view external returns (bool) {
        if (subscribers[_user] > block.timestamp) {
            return true;
        } else {
            return false;
        }
    }   
}