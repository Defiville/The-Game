//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "./IPLUG/IPLUGV1.sol";
import "./Ownable.sol";
import "./IERC20.sol";
import "./SafeMath.sol";
import "./Pausable.sol";
import "./SafeERC20.sol";

abstract contract IdleYield {
    function mintIdleToken(uint256 amount, bool skipRebalance, address referral) external virtual returns(uint256);
    function redeemIdleToken(uint256 amount) external virtual returns(uint256);
    function balanceOf(address user) external virtual returns(uint256);
    function tokenPrice() external virtual view returns(uint256);
    function userAvgPrices(address user) external virtual view returns(uint256);
    function fee() external virtual view returns(uint256);
}

contract PLUGIDLEV1 is IPLUGV1, Ownable, Pausable {
    
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    uint256 private constant ONE_18 = 10**18;
    uint256 private constant FULL_ALLOC = 100000;
    
    address public constant override tokenWant = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // USDC
    address public constant override tokenStrategy = address(0x5274891bEC421B39D23760c04A6755eCB444797C); // IDLEUSDC
    address public override tokenReward = address(0x20a68F9e34076b2dc15ce726d7eEbB83b694702d); // ISLA
    IdleYield strategy = IdleYield(tokenStrategy);
    IERC20 iTokenWant = IERC20(tokenWant);
    
    // addresses to send interests generated
    address public rewardOutOne;
    address public rewardOutTwo;
    // it should be used only when plug balance has to move to another plug
    address public plugHelper;
    
    // Plug parameter
    uint256 public currentLevelCap = uint256(150000).mul(ONE_18); // 150K token want
    uint256 public plugLimit = uint256(50000).mul(ONE_18); // 50K plug limit
    uint256 public plugLevel;
    mapping (address => uint256) public tokenStrategyAmounts;
    mapping (address => uint256) public tokenWantAmounts;
    mapping (address => uint256) public tokenWantDonated;
    uint256 public usersTokenWant;
    uint256 public lastRebalanceTs;
    uint256 twInStrategyLastRebalance;
    uint256 public rebalancePeriod = 3 days;
    uint256 public rewardRate = 10**30;

    event PlugCharged(address user, uint256 amount, uint256 amountMinted);
    event PlugDischarged(address user, uint256 userAmount, uint256 rewardForUSer, uint256 rewardForPlug);
    event SentRewardToOutOne(address token, uint256 amount);
    event SentRewardToOutTwo(address token, uint256 amount);
    event Rebalance(uint256 amountEarned);

    constructor() {
        iTokenWant.approve(tokenStrategy, uint256(-1));
    }

    /**
     * Charge plug staking token want into idle.
     */
    function chargePlug(uint256 _amount) external override whenNotPaused() {
        usersTokenWant = usersTokenWant.add(_amount);
        require(usersTokenWant < plugLimit);
        iTokenWant.safeTransferFrom(msg.sender, address(this), _amount);
        require(_getPlugBalance(tokenWant) >= _amount);
        uint256 amountMinted = strategy.mintIdleToken(_amount, true, address(0));
        
        tokenStrategyAmounts[msg.sender] = tokenStrategyAmounts[msg.sender].add(amountMinted);
        tokenWantAmounts[msg.sender] = tokenWantAmounts[msg.sender].add(_amount);
        emit PlugCharged(msg.sender, _amount, amountMinted);
    }
    
    /**
     * Discharge plug withdrawing all token staked into idle
     * Choose the percentage to donate into the plug (0, 50, 100)
     * If there is any reward active it will be send respecting the actual reward rate
     */
    function dischargePlug(uint256 _plugPercentage) external override whenNotPaused() {
        _dischargePlug(_plugPercentage);
    }
    
    /**
     * Internal function to discharge plug
     */
    function _dischargePlug(uint256 _plugPercentage) internal {
        require(_plugPercentage == 0 || _plugPercentage == 50 || _plugPercentage == 100);
        uint256 userAmount = tokenWantAmounts[msg.sender];
        require(userAmount > 0);

        // transfer token want from IDLE to plug
        uint256 amountRedeemed = strategy.redeemIdleToken(tokenStrategyAmounts[msg.sender]);
        usersTokenWant = usersTokenWant.sub(userAmount); 

        // token want earned
        uint256 tokenEarned;
        uint256 rewardForUser;
        uint256 rewardForPlug;
        uint256 amountToDischarge;

        // it should be always greater, added for safe
        if (amountRedeemed <= userAmount) {
            tokenEarned = 0;
            userAmount = amountRedeemed;
        } else {
            tokenEarned = amountRedeemed.sub(userAmount);
            rewardForUser = tokenEarned; 
        }
        
        // calculate token earned percentage to donate into plug 
        if (_plugPercentage > 0 && tokenEarned > 0) {
            rewardForPlug = tokenEarned;
            rewardForUser = 0;
            if (_plugPercentage == 50) {
                rewardForPlug = rewardForPlug.div(2);
                rewardForUser = tokenEarned.sub(rewardForPlug);
            }
            uint256 rewardLeft = _getPlugBalance(tokenReward);
            if (rewardLeft > 0) {
                uint256 rewardWithRate = rewardForPlug.mul(rewardRate).div(ONE_18);
                _sendReward(rewardLeft, rewardWithRate); 
            }
            tokenWantDonated[msg.sender] = tokenWantDonated[msg.sender].add(rewardForPlug);
        }

        // transfer tokenWant userAmount to user
        amountToDischarge = userAmount.add(rewardForUser);
        _dischargeUser(amountToDischarge);
        emit PlugDischarged(msg.sender, userAmount, rewardForUser, rewardForPlug);
    }

    /**
     * Sending all token want owned by an user.
     */
    function _dischargeUser(uint256 _amount) internal {
        _sendTokenWant(_amount);
        tokenWantAmounts[msg.sender] = 0;
        tokenStrategyAmounts[msg.sender] = 0;
    }

    /**
     * Send token want to msg.sender.
     */
    function _sendTokenWant(uint256 _amount) internal {
        iTokenWant.safeTransfer(msg.sender, _amount); 
    }

    /**
     * Send token reward to users,
     */
    function _sendReward(uint256 _rewardLeft, uint256 _rewardWithRate) internal {
        if (_rewardLeft >= _rewardWithRate) {
            IERC20(tokenReward).safeTransfer(msg.sender, _rewardWithRate); 
        } else {
            IERC20(tokenReward).safeTransfer(msg.sender, _rewardLeft); 
        } 
    }
    
    /**
     * Rebalance plug every rebalance period.
     */
    function rebalancePlug() external override whenNotPaused() {
        _rebalancePlug();
    }
    
    /**
     * Internsal function for rebalance.
     */
    function _rebalancePlug() internal {
        require(lastRebalanceTs.add(rebalancePeriod) < block.timestamp);
        lastRebalanceTs = block.timestamp;
        
        uint256 twPlug = iTokenWant.balanceOf(address(this));
        
        uint256 twInStrategy;
        uint256 teInStrategy;
        uint256 teByPlug;
        
        // reinvest token want to strategy
        if (plugLevel == 0) {
            _rebalanceAtLevel0(twPlug);
        } else {
            twInStrategy = _getTokenWantInS();
            teInStrategy = twInStrategy.sub(twInStrategyLastRebalance);
            teByPlug = twPlug.add(teInStrategy);
            if (plugLevel == 1) {
                _rebalanceAtLevel1Plus(teByPlug.div(2));
            } else {
                _rebalanceAtLevel1Plus(teByPlug.div(3));
            }
        }
        twInStrategyLastRebalance = _getTokenWantInS();
    }
    
    /**
     * Rebalance plug at level 0
     * Mint all tokens want owned by plug to idle pool 
     */
    function _rebalanceAtLevel0(uint256 _amount) internal {
        uint256 mintedTokens = strategy.mintIdleToken(_amount, true, address(0));
        tokenStrategyAmounts[address(this)] = tokenStrategyAmounts[address(this)].add(mintedTokens); 
    }
    
    /**
     * Rebalance plug at level1+.
     * level1 -> 50% remain into plug and 50% send to reward1
     * level2+ -> 33.3% to plug 33.3% to reward1 and 33.3% to reward2
     */
    function _rebalanceAtLevel1Plus(uint256 _amount) internal {
        uint256 plugAmount = _getPlugBalance(tokenWant);
        uint256 amountToSend = _amount;
        
        if (plugLevel > 1) {
            amountToSend = amountToSend.mul(2);
        }
        
        if (plugAmount < amountToSend) {
            uint256 amountToRetrieveFromS = amountToSend.sub(plugAmount);
            uint256 amountToRedeem = amountToRetrieveFromS.div(_getRedeemPrice()).mul(ONE_18);
            strategy.redeemIdleToken(amountToRedeem);
            tokenStrategyAmounts[address(this)] = tokenStrategyAmounts[address(this)].sub(amountToRedeem);
        }
        
        // send to reward out 1
        _transferToOutside(tokenWant, rewardOutOne, _amount);
        
        if (plugLevel > 1) {
            _transferToOutside(tokenWant, rewardOutTwo, _amount);
        }
        
        //send all remain token want from plug to idle strategy
        uint256 balanceLeft = plugAmount.sub(amountToSend);
        if (balanceLeft > 0) {
            _rebalanceAtLevel0(balanceLeft);
        }
    }

    /**
     * Upgrade plug to the next level.
     */
    function upgradePlug(uint256 _nextLevelCap) external override onlyOwner {
        require(_nextLevelCap > currentLevelCap && plugTotalAmount() > currentLevelCap);
        require(rewardOutOne != address(0));
        if (plugLevel >= 1) {
            require(rewardOutTwo != address(0));
            require(plugHelper != address(0));
        }
        plugLevel = plugLevel + 1;
        currentLevelCap = _nextLevelCap;
    }
    
    /**
     * Redeem all token owned by plug from idle strategy.
     */
    function safePlugExitStrategy(uint256 _amount) external onlyOwner {
        strategy.redeemIdleToken(_amount);
        tokenStrategyAmounts[address(this)] = tokenStrategyAmounts[address(this)].sub(_amount);
        twInStrategyLastRebalance = _getTokenWantInS();
    }
    
    /**
     * Transfer token want to factory.
     */
    function transferToHelper() external onlyOwner {
        require(plugHelper != address(0));
        uint256 amount = iTokenWant.balanceOf(address(this));
        _transferToOutside(tokenWant, plugHelper, amount);
    }
    
    /**
     * Transfer token different than token strategy to external allowed address (ex IDLE, COMP, ecc).
     */
    function transferToRewardOut(address _token, address _rewardOut) external onlyOwner {
        require(_token != address(0) && _rewardOut != address(0));
        require(_rewardOut == rewardOutOne || _rewardOut == rewardOutTwo);
        // it prevents to tranfer idle tokens outside
        require(_token != tokenStrategy);
        uint256 amount = IERC20(_token).balanceOf(address(this));
        _transferToOutside(_token, _rewardOut, amount);
    }
    
    /**
     * Transfer any token to external address.
     */
    function _transferToOutside(address _token, address _outside, uint256 _amount) internal {
      IERC20(_token).safeTransfer(_outside, _amount);  
    }

    /**
     * Approve token to spender.
     */
    function safeTokenApprore(address _token, address _spender, uint256 _amount) external onlyOwner {
        IERC20(_token).approve(_spender, _amount);
    }
    
    /**
     * Set the current level cap.
     */
    function setCurrentLevelCap(uint256 _newCap) external onlyOwner {
        require(_newCap > plugTotalAmount());
        currentLevelCap = _newCap;
    }
    
    /**
     * Set a new token reward.
     */
    function setTokenReward(address _tokenReward) external onlyOwner {
        tokenReward = _tokenReward;
    }

    /**
     * Set the new reward rate in decimals (18).
     */
    function setRewardRate(uint256 _rate) external onlyOwner {
        rewardRate = _rate;
    }
    
    /**
     * Set the first reward pool address.
     */
    function setRewardOutOne(address _reward) external onlyOwner {
        rewardOutOne = _reward;
    }
    
    /**
     * Set the second reward pool address.
     */
    function setRewardOutTwo(address _reward) external onlyOwner {
        rewardOutTwo = _reward;
    }
    
    /**
     * Set the plug helper address.
     */
    function setPlugHelper(address _plugHelper) external onlyOwner {
        plugHelper = _plugHelper;
    }
    
    /**
     * Set the new rebalance period duration.
     */ 
    function setRebalancePeriod(uint256 _newPeriod) external onlyOwner {
        // at least 12 hours (60 * 60 * 12)
        require(_newPeriod >= 43200);
        rebalancePeriod = _newPeriod;
    }

    /**
     * Set the new plug cap for token want to store in it.
     */ 
    function setPlugUsersLimit(uint256 _newLimit) external onlyOwner {
        require(_newLimit > plugLimit);
        plugLimit = _newLimit;
    }

    /**
     * Get the current reedem price.
     * @notice function helper for retrieving the idle token price counting fees, developed by @emilianobonassi
     * https://github.com/emilianobonassi/idle-token-helper
     */
    function _getRedeemPrice() view internal returns (uint256 redeemPrice) {
        uint256 userAvgPrice = strategy.userAvgPrices(address(this));
        uint256 currentPrice = strategy.tokenPrice();

        // When no deposits userAvgPrice is 0 equiv currentPrice
        // and in the case of issues
        if (userAvgPrice == 0 || currentPrice < userAvgPrice) {
            redeemPrice = currentPrice;
        } else {
            uint256 fee = strategy.fee();

            redeemPrice = ((currentPrice.mul(FULL_ALLOC))
                .sub(
                    fee.mul(
                         currentPrice.sub(userAvgPrice)
                    )
                )).div(FULL_ALLOC);
        }

        return redeemPrice;
    }

    /**
     * Get the plug balance of a token.
     */
    function _getPlugBalance(address _token) internal view returns(uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    /**
     * Get the plug balance of token want into idle strategy.
     */
    function _getTokenWantInS() internal view returns (uint256) {
        uint256 tokenPrice = _getRedeemPrice();
        return tokenStrategyAmounts[address(this)].mul(tokenPrice).div(ONE_18);
    }

    /**
     * Get the plug total amount between the ineer and the amount store into idle.
     */
    function plugTotalAmount() public view returns(uint256) {
        uint256 tokenWantInStrategy = _getTokenWantInS();
        return iTokenWant.balanceOf(address(this)).add(tokenWantInStrategy);
    }
}