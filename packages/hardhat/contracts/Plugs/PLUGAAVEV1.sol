//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "./IPLUG/IPLUGV1.sol";
import "./Ownable.sol";
import "./IERC20.sol";
import "./SafeMath.sol";
import "./Pausable.sol";
import "./SafeERC20.sol";

abstract contract LendingPool {
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external virtual;
    function withdraw(address asset, uint256 amount, address to) external virtual;
}

abstract contract CurvePool {
    function deposit() external virtual;
    function withdraw() external virtual;
}

// PLUG for AAVE+Curve lending pools 
contract PLUGAAVEV1 is IPLUGV1, Ownable, Pausable {
    
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    enum PlugStrategy {
        Aave,
        Curve,
        Both
    }

    struct PlugStrategy {

    }
    
    uint256 private constant ONE_18 = 10**18;
    
    // AAVE
    address public constant override tokenAave = address(0x27F8D03b3a2196956ED754baDc28D73be8830A6e); // amDAI token
    address public constant aaveLending = address(0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf); // dai lending
    address public override tokenReward = address(); // ISLA pos tbd
    LendingPool strategy = LendingPool(aaveLending);

    // Curve
    address public cPool = address(0x445FE580eF8d70FF569aB36e80c647af338db351);
    address public cGauge;
    
    // addresses to send interests generated
    address public rewardOut;
    // it should be used only when plug balance has to move to another plug
    address public plugHelper;
    address public governance;
    
    // Plug parameter
    //uint256 public plugLimit = uint256(50000).mul(ONE_18); // 50K plug limit
    mapping (address => mapping (address => uint256)) public tokenWantsAmounts;
    //mapping (address => mapping (address => uint256)) public tokenCRV; // am3CRV
    mapping (address => mapping (address => uint256)) public tokenWantsDonated;
    mapping (address => bool) tokenWantWL;
    mapping (address => address) aTokens;
    mapping (address => uint256) tokenWantT;
    mapping (address => uint256) plugLimits;
    uint256 public lastRebalanceTs;
    uint256 twInStrategyLastRebalance;
    uint256 public rebalancePeriod = 1 weeks;
    uint256 public rewardRate = ONE_18;


    event PlugCharged(address indexed user, address[] tokensWant, uint256[] amounts);
    event PlugDischarged(address indexed user, uint256 userAmount, uint256 rewardForUSer, uint256 rewardForPlug);
    event SentRewardToRewardOut(address token, uint256 amount);
    event Rebalance(uint256 amountEarned);

    constructor() {
    }

    function enableTokenWant(address _tokenWant, address _aToken, uint256 _plugLimit) external onlyOwner {
        require(tokenWantWL[_tokenWant] != false, 'Already enabled');
        tokenWantWL[_tokenWant] = true;
        aTokens[_tokenWant] = _aToken;
        plugLimits[_tokenWant] = _plugLimit;
        IERC20(_tokenWant).approve(aaveLending, uint256(-1));
        IERC20(_aToken).approve(cPool, uint256(-1));
    }

    function disableTokenWant(address _tokenWant) external onlyOwner {
        require(tokenWantWL[_tokenWant] == true, 'Already disabled');
        tokenWantWL[_tokenWant] = false;
    }

    /**
     * Charge plug staking token want into aave lending pool.
     */
    function reservedFor(PlugStrategy _strategy, address[] memory _tokensWant, uint256[] memory _amounts) external override whenNotPaused() {
        if (_strategy != PlugStrategy.Curve) {
            _putInAave(_tokensWant, _amounts); // aave
            if (_strategy == PlugStrategy.Both) {
                _putInCurveA(_tokensWant, _amounts); // amDAI
            }
        } else {
            _putInCurve(_tokensWant, _amounts); // DAI
        }
    }
 
    /**
     * Charge plug staking token want into aave lending pool.
     */
    function chargePlug(address[] memory _tokensWant, uint256[] memory _amounts) external override whenNotPaused() {
        _chargePlug(_tokenWant, _amounts);
    }

    function _chargePlug(address[] memory _tokensWant, uint256[] memory _amounts) external override whenNotPaused() {
        for (uint256 i = 0; i < _tokensWant.length; i++) {
            require(tokenWantWL[_tokensWant[i]], 'Not in Whitelist');
            tokenWantT[_tokensWant[i]] = tokenWantT[_tokensWant[i]].add(_amount);
            require(tokenWantT[_tokensWant[i]] < plugLimits[_tokensWant[i]]);
            IERC20(_tokensWant[i]).safeTransferFrom(msg.sender, address(this), _amounts[i]);
            require(_getPlugBalance(_tokensWant[i]) >= _amounts[i]);
            tokenWantsAmounts[_tokensWant[i]][msg.sender] = tokenWantsAmounts[_tokensWant[i]][msg.sender].add(_amounts[i]);
        }
    }

    // it transfer users funds to another plug
    function transferTo(
        address _plugA, 
        address[] _tokens, 
        uint256[] _amounts
    ) external {
        IPLUGV1(_plugA).chargePlug(_tokens, _amounts);
    }

    function _putInAave(address[] memory _tokensWant, uint256[] memory _amounts) internal {
        for (uint256 i = 0; i < _tokensWant.length; i++) {
            require(tokenWantWL[_tokensWant[i]], 'Not in Whitelist');
            tokenWantT[_tokensWant[i]] = tokenWantT[_tokensWant[i]].add(_amount);
            require(tokenWantT[_tokensWant[i]] < plugLimits[_tokensWant[i]]);
            IERC20(_tokensWant[i]).safeTransferFrom(msg.sender, address(this), _amounts[i]);
            require(_getPlugBalance(_tokensWant[i]) >= _amounts[i]);
            strategy.deposit(_tokensWant[i], _amounts[i], address(this), 0);
            tokenWantsAmounts[_tokensWant[i]][msg.sender] = tokenWantsAmounts[_tokensWant[i]][msg.sender].add(_amounts[i]);
        }
        emit PlugCharged(msg.sender, _tokensWant, _amounts);
    }

    function _putInCurveA(address[] memory _aTokens, uint256[] memory _amounts) internal {
        for (uint256 i = 0; i < _aTokens.length; i++) {
        }
    }

    function _putInCurve(address[] memory _tokensWant, uint256[] memory _amounts) internal {
        for (uint256 i = 0; i < _tokensWant.length; i++) {
            require(tokenWantWL[_tokensWant[i]], 'Not in Whitelist');
            tokenWantT[_tokensWant[i]] = tokenWantT[_tokensWant[i]].add(_amount);
            require(tokenWantT[_tokensWant[i]] < plugLimits[_tokensWant[i]]);
            IERC20(_tokensWant[i]).safeTransferFrom(msg.sender, address(this), _amounts[i]);
            require(_getPlugBalance(_tokensWant[i]) >= _amounts[i]);
            strategy.deposit(_tokensWant[i], _amounts[i], address(this), 0);
            tokenWantsAmounts[_tokensWant[i]][msg.sender] = tokenWantsAmounts[_tokensWant[i]][msg.sender].add(_amounts[i]);
        }
    }
    
    /**
     * Discharge plug withdrawing all token staked into idle
     * Choose the percentage to donate into the plug (0, 50, 100)
     * If there is any reward active it will be send respecting the actual reward rate
     */
    function dischargePlug(address _tokenWant, uint256 _amount, uint256 _plugPercentage) external override whenNotPaused() {
        _dischargePlug(_tokenWant, _amount, _plugPercentage);
    }
    
    /**
     * Internal function to discharge plug
     */
    function _dischargePlug(address _tokenWant, uint256 _amount, uint256 _plugPercentage) internal {
        //require(_plugPercentage == 0 || _plugPercentage == 50 || _plugPercentage == 100);
        require(_plugPercentage <= 100);
        uint256 userAmount = tokenWantsAmounts[_tokenWant][msg.sender];
        require(userAmount >= _amount);

        // transfer token want from IDLE to plug
        uint256 twBefore = _getPlugBalance(_tokenWant);
        strategy.withdraw(_tokenWant, _amount, msg.sender);
        uint256 twAfter = _getPlugBalance(_tokenWant);

        uint256 amountRedeemed = twAfter.sub(twBefore);

        // token want earned
        uint256 tokenEarned;
        uint256 rewardForUser;

        if (amountRedeemed <= userAmount) {
            tokenEarned = 0;
            userAmount = amountRedeemed;
        } else {
            tokenEarned = amountRedeemed.sub(userAmount);
            rewardForUser = tokenEarned;
        }
        tokenWantT[_tokenWant] = tokenWantT[_tokenWant].sub(_amount);
        //usersTokenWant = usersTokenWant.sub(_amount); 

        uint256 rewardForPlug;
        uint256 amountToDischarge;
        
        // calculate token earned percentage to donate into plug 
        if (_plugPercentage > 0 && tokenEarned > 0) {
            rewardForPlug = tokenEarned;
            rewardForUser = 0;
            /*if (_plugPercentage == 50) {
                rewardForPlug = rewardForPlug.div(2);
                rewardForUser = tokenEarned.sub(rewardForPlug);
            }*/
            rewardForPlug = rewardForPlug.div(100).mul(_plugPercentage);
            rewardForUser = tokenEarned.sub(rewardForPlug);
            uint256 rewardLeft = _getPlugBalance(tokenReward);
            if (rewardLeft > 0) {
                uint256 rewardWithRate = rewardForPlug.mul(rewardRate).div(ONE_18);
                _sendReward(rewardLeft, rewardWithRate); 
            }
            tokenWantsDonated[_tokenWant][msg.sender] = tokenWantsDonated[_tokenWant][msg.sender].add(rewardForPlug);
        }

        // transfer tokenWant userAmount to user
        amountToDischarge = userAmount.add(rewardForUser);
        _dischargeUser(amountToDischarge);
        emit PlugDischarged(msg.sender, userAmount, rewardForUser, rewardForPlug);
    }

    /**
     * Sending all token want owned by an user.
     */
    function _dischargeUser(address _tokenWant, uint256 _amount) internal {
        _sendTokenWant(_tokenWant, _amount);
        tokenWantsAmounts[_tokenWant][msg.sender] = 0;
    }

    /**
     * Send token want to msg.sender.
     */
    function _sendTokenWant(address _tokenWant, uint256 _amount) internal {
        IERC20(_tokenWant).safeTransfer(msg.sender, _amount); 
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
    function rebalancePlug(address _tokenWant) external override whenNotPaused() {
        _rebalancePlug(_tokenWant);
    }
    
    /**
     * Internal function for rebalance.
     */
    function _rebalancePlug(address _tokenWant) internal {
        require(lastRebalanceTs.add(rebalancePeriod) < block.timestamp);
        lastRebalanceTs = block.timestamp;
        
        uint256 twPlug = IERC20(_tokenWant).balanceOf(address(this));
        
        uint256 twInStrategy;
        uint256 teInStrategy;
        uint256 teByPlug;
        
        // reinvest token want to strategy
        if (rewardOut == address(0)) {
            _allToLending(twPlug);
        } else {
            twInStrategy = _getTokenWantInS();
            teInStrategy = twInStrategy.sub(twInStrategyLastRebalance);
            teByPlug = twPlug.add(teInStrategy);
            _rebalance(_tokenWant, teByPlug.div(2));
        }
        twInStrategyLastRebalance = _getTokenWantInS();
    }
    
    /**
     * Rebalance plug at level 0
     * Mint all tokens want owned by plug to idle pool 
     */
    function _allToLending(uint256 _amount) internal {
        uint256 mintedTokens = strategy.mintIdleToken(_amount, true, address(0));
        //tokenStrategyAmounts[address(this)] = tokenStrategyAmounts[address(this)].add(mintedTokens); 
    }
    
    /**
     * Internal function to rebalance plug when reward address is set.
     * 50% remain into plug and 50% send to reward out
     */
    function _rebalance(address _tokenWant, uint256 _amount) internal {
        uint256 plugAmount = _getPlugBalance(_tokenWant);
        uint256 amountToSend = _amount;
        
        if (plugAmount < amountToSend) {
            uint256 amountToRetrieveFromS = amountToSend.sub(plugAmount);
            uint256 amountToRedeem = amountToRetrieveFromS.div(_getRedeemPrice()).mul(ONE_18);
            strategy.redeemIdleToken(amountToRedeem);
            //tokenStrategyAmounts[address(this)] = tokenStrategyAmounts[address(this)].sub(amountToRedeem);
        }
        
        // send to reward out 1
        _transferToOutside(_tokenWant, rewardOut, _amount);
        
        //send all remain token want from plug to idle strategy
        uint256 balanceLeft = plugAmount.sub(amountToSend);
        if (balanceLeft > 0) {
            _allToLending(balanceLeft);
        }
    }

    // it will deposit to curve amDAI/amUSDC/amUSDT pool on polygon network
    function depositToCurve(address[] memory _tokens, uint256[] memory _amounts) external onlyOwner {

    }

    // withdraw from curve pool
    function withdrawFromCurve(address[] memory _tokens, uint256[] memory _amounts) external onlyOwner {

    }

    // redeem wmatic from curve gauge
    function withdrawFromGauge(uint256 _amount) external onlyOwner {

    }
    
    /**
     * Redeem all token owned by plug from idle strategy.
     */
    function safePlugExitStrategy(uint256 _amount) external onlyOwner {
        strategy.redeemIdleToken(_amount);
        //tokenStrategyAmounts[address(this)] = tokenStrategyAmounts[address(this)].sub(_amount);
        twInStrategyLastRebalance = _getTokenWantInS();
    }
    
    /**
     * Transfer token want to factory.
     */
    function transferToHelper(address _tokenWant) external onlyOwner {
        require(plugHelper != address(0));
        uint256 amount = IERC20().balanceOf(address(this));
        _transferToOutside(_tokenWant, plugHelper, amount);
    }
    
    /**
     * Transfer token different than token strategy to external allowed address (ex IDLE, COMP, ecc).
     */
    function transferToRewardOut(address _token, address _rewardOut) external onlyOwner {
        require(_token != address(0) && _rewardOut != address(0));
        require(_rewardOut == rewardOut);
        // it prevents to tranfer aave token tokens outside
        //require(_token != tokenStrategy);
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
        rewardOut = _reward;
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
    function setPlugUsersLimit(address _tokenWant, uint256 _newLimit) external onlyOwner {
        require(_newLimit > plugLimits[_tokenWant]);
        plugLimits[_tokenWant] = _newLimit;
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
    function _getTokenWantInS(address _token) internal view returns (uint256) {
        return tokenWantsAmounts[_token][address(this)].
        //uint256 tokenPrice = _getRedeemPrice();
        //return tokenStrategyAmounts[address(this)].mul(tokenPrice).div(ONE_18);
    }

    /**
     * Get the plug total amount between the ineer and the amount store into idle.
     */
    function plugTotalAmount(address _token) public view returns(uint256) {
        uint256 tokenWantInStrategy = _getTokenWantInS(_token);
        return IERC20(_token).balanceOf(address(this)).add(tokenWantInStrategy);
    }
}