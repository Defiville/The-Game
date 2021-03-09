//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "./IPLUGV1.sol";
import "./Ownable.sol";
import "./IERC20.sol";
import "./SafeMath.sol";

abstract contract IdleYield {
    function mintIdleToken(uint256 _amount, bool _skipRebalance, address _referral) external virtual returns(uint256);
    function redeemIdleToken(uint256 _amount) external virtual returns(uint256);
    function balanceOf(address user) external virtual returns(uint256);
    function tokenPrice() external virtual view returns(uint256);
}

contract PLUGIDLEV1 is IPLUGV1, Ownable {
    
    using SafeMath for uint256;
    
    uint256 private constant TEN_18 = 10**18;
    
    address public constant override tokenWant = address(0x6B175474E89094C44Da98b954EedeAC495271d0F); // DAI
    address public constant override tokenStrategy = address(0x3fE7940616e5Bc47b0775a0dccf6237893353bB4); // IDLEDAI
    address public override tokenReward = address(0x20a68F9e34076b2dc15ce726d7eEbB83b694702d); // ISLA 
    IdleYield strategy = IdleYield(tokenStrategy);
    bool isPlugActive = false;
    
    // IDLE Governance
    address constant idleToken = address(0x875773784Af8135eA0ef43b5a374AaD105c5D39e); // IDLE
    address constant compToken = address(0xc00e94Cb662C3520282E6f5717214004A7f26888); // COMP
    
    // addresses to send interests generated
    address public rewardOutOne;
    address public rewardOutTwo;
    // it should be used only when plug balance has to move to another plug
    address plugFactory;
    
    // Plug parameter
    uint256 public currentLevelCap;
    uint256 public plugLevel;
    mapping (address => uint256) public tokenStrategyAmounts;
    mapping (address => uint256) public tokenWantAmounts;
    uint256 tokenStrategyTotalAmount;
    uint256 tokenWantTotalAmount;
    uint256 public lastRebalanceTs;
    uint256 twInStrategyLastRebalance;
    uint256 public rebalancePeriod = 1 weeks;
    
    event PlugCharged(address user, uint256 amount);
    event PlugDischarged(address user, uint256 amount);
    event RewardDistributed(address user, uint256 amount);
    event SentRewardToOutOne(uint256 amount);
    event SentRewardToOutTwo(uint256 amount);
    event Rebalance(uint256 amountEarned);
    
    constructor() {
    }

    // activate plug for the first time
    function activatePlug() external override onlyOwner {
        require(!isPlugActive, 'Plug already activated');
        IERC20(tokenWant).approve(tokenStrategy, uint256(-1));
        currentLevelCap = uint256(150000).mul(TEN_18); // 150K token want
        isPlugActive = true;
    }
    
    // upgrade plug to the next level
    function upgradePlug(uint256 _nextLevelCap) external override onlyOwner {
        require(plugTotalAmount() > currentLevelCap);
        require(rewardOutOne != address(0));
        if (plugLevel >= 1) {
            require(rewardOutTwo != address(0));
            require(plugFactory != address(0));
        }
        plugLevel = plugLevel + 1;
        currentLevelCap = _nextLevelCap;
    }
    
    // charge plug staking token want
    // amount minted will remain into the plug
    function chargePlug(uint256 _amount) external override {
        require(isPlugActive);
        IERC20(tokenWant).transferFrom(msg.sender, address(this), _amount);
        require(IERC20(tokenWant).balanceOf(address(this)) >= _amount);
        uint256 amountMinted = strategy.mintIdleToken(_amount, true, address(0));
        
        tokenStrategyAmounts[msg.sender] = tokenStrategyAmounts[msg.sender].add(amountMinted);
        tokenWantAmounts[msg.sender] = tokenWantAmounts[msg.sender].add(_amount);
        emit PlugCharged(msg.sender, _amount);
    }
    
    // discharge plug withdrawing all token staked into it
    // choose the percentage to donate into it for increasing the plug value
    // if there is any reward active it will be send to the user with the same amount of token donated (Rate 1:1)
    function dischargePlug(uint256 _plugPercentage) external override {
        require(isPlugActive);
        require(_plugPercentage <= 100);
        // transfer token want from IDLE to plug
        uint256 userAmount = tokenWantAmounts[msg.sender];
        uint256 amountRedeemed = strategy.redeemIdleToken(tokenStrategyAmounts[msg.sender]);
        
        // token want earned
        uint256 tokenEarned = amountRedeemed.sub(userAmount);
        
        // calculate token earned percentage to donate into plug 
        uint256 rewardForUser;
        if (_plugPercentage > 0) {
            uint256 rewardForPlug = tokenEarned.div(100).mul(_plugPercentage);
            tokenWantAmounts[address(this)] = tokenWantAmounts[address(this)].add(rewardForPlug);
            rewardForUser = tokenEarned.sub(rewardForPlug);
            // distribute rewardToken if there is any
            if (IERC20(tokenReward).balanceOf(address(this)) >= rewardForUser) {
                IERC20(tokenReward).transfer(msg.sender, rewardForUser); 
            }
        } else {
            rewardForUser = tokenEarned;
        }
        
        // transfer tokenWant userAmount to user
        IERC20(tokenWant).transfer(msg.sender, userAmount.add(rewardForUser));
        
        tokenWantAmounts[msg.sender] = 0;
        tokenStrategyAmounts[msg.sender] = 0;
        emit PlugDischarged(msg.sender, amountRedeemed);
    }
    
    // everyone can call the rebalance, one time per rebalance period 
    function rebalancePlug() external override {
        require(lastRebalanceTs.add(rebalancePeriod) < block.timestamp);
        lastRebalanceTs = block.timestamp;
        
        uint256 tsPlug;
        uint256 twPlug = tokenWantAmounts[address(this)];
        
        uint256 twInStrategy;
        uint256 teInStrategy;
        uint256 teByPlug;
        
        // reinvest token want to strategy
        if (plugLevel == 0) {
            _rebalanceAtLevel0(twPlug);
        } else {
            if (tsPlug > 0) {
                tsPlug = tokenStrategyAmounts[address(this)];
                twInStrategy = tsPlug.mul(strategy.tokenPrice());
                teInStrategy = twInStrategy.sub(twInStrategyLastRebalance);
                twInStrategyLastRebalance = twInStrategy;
            }
            teByPlug = twPlug.add(teInStrategy);
            if (plugLevel == 1) {
                _rebalanceAtLevel1Plus(teByPlug.div(2), teInStrategy);
            } else {
                _rebalanceAtLevel1Plus(teByPlug.div(3), teInStrategy);
            }
        }
    }
    
    function _rebalanceAtLevel0(uint256 _amount) internal {
        uint256 mintedTokens = strategy.mintIdleToken(_amount, true, address(0));
        tokenWantAmounts[address(this)] = 0;
        tokenStrategyAmounts[address(this)] = tokenStrategyAmounts[address(this)].add(mintedTokens);  
    }
    
    function _rebalanceAtLevel1Plus(uint256 _amount, uint256 _teInStrategy) internal {
        if (_amount > _teInStrategy) {
            uint256 amountToSendInStrategy = _amount.sub(_teInStrategy);
            uint256 tokenMinted = strategy.mintIdleToken(amountToSendInStrategy, true, address(0));
            tokenStrategyAmounts[address(this)] = tokenStrategyAmounts[address(this)].add(tokenMinted);
            tokenWantAmounts[address(this)] = tokenWantAmounts[address(this)].sub(amountToSendInStrategy);
        }
        if (_amount < _teInStrategy) {
            uint256 amountToRetrieveFromStrategy = _teInStrategy.sub(_amount);
            uint256 tokenRetrieved = strategy.redeemIdleToken(amountToRetrieveFromStrategy);
            tokenStrategyAmounts[address(this)] = tokenStrategyAmounts[address(this)].sub(amountToRetrieveFromStrategy);
            tokenWantAmounts[address(this)] = tokenWantAmounts[address(this)].add(tokenRetrieved);
        }
        // send to reward out 1
        _transferToOutside(tokenWant, rewardOutOne, _amount);
        
        if (plugLevel > 1) {
            _transferToOutside(tokenWant, rewardOutTwo, _amount);
        }
    }
    
    // exit from strategy reediming all tokens strategy owned by plug
    function safePlugExitStrategy() external onlyOwner {
        uint256 tokenRedeemed = strategy.redeemIdleToken(tokenStrategyAmounts[address(this)]);
        tokenWantAmounts[address(this)] = tokenWantAmounts[address(this)].add(tokenRedeemed);
    }
    
    // Move plug token want total amount to the plug factory for sending to another plug
    function transferToFactory() external override onlyOwner {
        require(plugFactory != address(0));
        uint256 amount = IERC20(tokenWant).balanceOf(address(this));
        _transferToOutside(tokenWant, plugFactory, amount);
        tokenWantAmounts[address(this)] = 0;
    }
    
    // Transfer in case of plug is accumulating tokens different than token strategy (ex IDLE, COMP, ecc)
    // transfer permitted only to rewardOutOne or rewardOutTwo
    function transferToRewardOut(address _token, address _rewardOut) external onlyOwner {
        // avoid to transfer idle token strategy owned by users
        require(_token != address(0) && _token != tokenStrategy);
        require(_rewardOut != address(0) && (_rewardOut == rewardOutOne || _rewardOut == rewardOutTwo));
        uint256 amount = IERC20(_token).balanceOf(address(this));
        _transferToOutside(_token, _rewardOut, amount);
    }
    
    function _transferToOutside(address _token, address _outside, uint256 _amount) internal {
      IERC20(_token).transfer(_outside, _amount);  
    }
    
    function plugTotalAmount() public view override returns(uint256) {
        uint256 tokenPrice = strategy.tokenPrice();
        uint256 tokenWantInStrategy = tokenStrategyAmounts[address(this)].mul(tokenPrice);
        return tokenWantAmounts[address(this)].add(tokenWantInStrategy);
    }
    
    function decreaseCurrentLevelCap(uint256 _newCap) external onlyOwner {
        require(currentLevelCap > _newCap && _newCap > plugTotalAmount());
        currentLevelCap = _newCap;
    }
    
    function setTokenReward(address _tokenReward) external onlyOwner {
        tokenReward = _tokenReward;
    }
    
    function setRewardOutOne(address _reward) external onlyOwner {
        rewardOutOne = _reward;
    }
    
    function setRewardOutTwo(address _reward) external onlyOwner {
        rewardOutTwo = _reward;
    }
    
    function setPlugFactory(address _plugFactory) external onlyOwner {
        plugFactory = _plugFactory;
    }
    
    function setRebalancePeriod(uint256 _newPeriod) external onlyOwner {
        rebalancePeriod = _newPeriod;
    }
}