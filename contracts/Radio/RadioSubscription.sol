//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "./SafeMath.sol";
import "./SafeERC20.sol";
import "./Ownable.sol";

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
    
    event AddArtist(address artist);
    event Subscribe(address indexed user, uint256 months);
    event TipRadio(address indexed user, address token, uint256 amount);
    event TipArtist(address indexed user, address indexed artist, uint256 amount);
    event RedeemArtistShare(address indexed artist, uint256 amount);
    
    constructor(address[] memory _artistsWL, address _tokenWant) {
        tokenWantA = _tokenWant;
        tokenWant = IERC20(tokenWantA);
        for(uint256 i = 0; i < _artistsWL.length; i++) {
            wlArtists[_artistsWL[i]] = true;
        }
    }
    
    function subscribe(uint256 _months) external {
        uint256 totalAmount = monthlyPrice * _months;
        
        _receiveToken(tokenWantA, totalAmount);
        
        artistsJar = totalAmount.div(100).mul(percentageForArtists);
        radioJar = totalAmount.sub(artistsJar);
        require(radioJar.add(artistsJar) == totalAmount);
        
        if (subscribers[msg.sender] == 0) {
            subscribers[msg.sender] = block.timestamp.add(_months.mul(monthSeconds));
        } else {
            subscribers[msg.sender] = subscribers[msg.sender].add(_months.mul(monthSeconds));
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
        emit TipArtist(msg.sender, _artist, _amount);
    }
    
    function _receiveToken(address _token, uint256 _amount) internal {
        IERC20 token = IERC20(_token);
        uint256 balanceBefore = token.balanceOf(address(this));
        token.transferFrom(msg.sender, address(this), _amount);
        uint256 balanceAfter = token.balanceOf(address(this));
        require(balanceAfter == balanceBefore.add(_amount));
    }
    
    function addArtist(address _artist) external onlyOwner {
        require(wlArtists[_artist] == false);
        wlArtists[_artist] = true;
        emit AddArtist(_artist);
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
        tokenWant.transfer(msg.sender, _amount);
        artistsShare[msg.sender] = artistsShare[msg.sender].sub(_amount);
    }
    
    function earn(address _token, address _recipient, uint256 _amount) external onlyOwner {
        if (_token == tokenWantA) {
            require(_amount <= radioJar);
            radioJar = radioJar.sub(_amount);
        }
        uint256 balanceBefore = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(_recipient, _amount);
        uint256 balanceAfter = IERC20(_token).balanceOf(address(this));
        require(balanceBefore.sub(balanceAfter) == _amount);
    }

    function setArtistsPercentage(uint256 _newPercentage) external onlyOwner {
        require(_newPercentage <= 100);
        percentageForArtists = _newPercentage;
    }

    function setMonthlyCost(uint256 newPrice) external onlyOwner {
        require(newPrice >= ONE_18); // at least 1 xDAI
        monthlyPrice = newPrice;
    }
    
    function isSubscribed(address _user) view external returns (bool) {
        if (subscribers[_user] > block.timestamp) {
            return true;
        } else {
            return false;
        }
    }   
}