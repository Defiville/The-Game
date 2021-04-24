//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "./IPLUG/IPLUGV1.sol";
import "./Pausable.sol";
import "./SafeMath.sol";
import "./SafeERC20.sol";
import "./IERC20.sol";

abstract contract stakeDaoVault {
    function deposit(uint256 amount) external virtual;
    function withdraw(uint256 shares) external virtual;
    function balanceOf(address user) external virtual returns(uint256);
}

contract PLUGSTAKEV1 is IPLUGV1, Pausable {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 private constant ONE_18 = 10**18;

    address public override tokenWant = address(0x194eBd173F6cDacE046C53eACcE9B953F28411d1); //eursCRV
    address public override tokenStrategy = address(0xCD6997334867728ba14d7922f72c893fcee70e84); //sdEURSCRV
    address public override tokenReward; // ISLA
    stakeDaoVault strategy = stakeDaoVault(tokenStrategy);
    IERC20 iTokenWant = IERC20(tokenWant);

    mapping (address => uint256) public tokenWantAmounts;
    mapping (address => uint256) public tokenStrategyAmounts;
    mapping (address => uint256) public tokenWantDonated;

    uint256 usersTokenWant;

    uint256 public plugLimit = uint256(50000).mul(ONE_18); // 50K plug limit

    event PlugCharged(address user, uint256 amount, uint256 amountMinted);
    event PlugDischarged(address user, uint256 userAmount, uint256 rewardForUSer, uint256 rewardForPlug);
    event SentRewardToOutOne(address token, uint256 amount);
    event SentRewardToOutTwo(address token, uint256 amount);
    event Rebalance(uint256 amountEarned);

    /**
     * Charge plug staking token want into idle.
     */
    function chargePlug(uint256 _amount) external override whenNotPaused() {
        usersTokenWant = usersTokenWant.add(_amount);
        require(usersTokenWant < plugLimit);

        iTokenWant.safeTransferFrom(msg.sender, address(this), _amount);
        require(_getPlugBalance(tokenWant) >= _amount);

        uint256 vaultBefore = strategy.balanceOf(address(this));
        strategy.deposit(_amount);
        uint256 vaultAfter = strategy.balanceOf(address(this));
        uint256 amountMinted = vaultAfter.sub(vaultBefore);
        
        tokenStrategyAmounts[msg.sender] = tokenStrategyAmounts[msg.sender].add(amountMinted);
        tokenWantAmounts[msg.sender] = tokenWantAmounts[msg.sender].add(_amount);
        emit PlugCharged(msg.sender, _amount, amountMinted);
    }

    function dischargePlug(uint256 _plugPercentage) external override {

    }

    /**
     * Internal function to discharge plug
     */
    /*function _dischargePlug(uint256 _plugPercentage) internal {
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
    }*/

    function upgradePlug(uint256 _nextLevelCap) external override {

    }

    function rebalancePlug() external override {

    }

    function _getPlugBalance(address _token) internal view returns(uint256) {
        return IERC20(_token).balanceOf(address(this));
    }
}