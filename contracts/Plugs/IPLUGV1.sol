//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

interface IPLUGV1 {
    function activatePlug() external;
    function upgradePlug(uint256 nextLevelCap) external;
    function chargePlug(uint256 amount) external;
    function dischargePlug(uint256 plugPercentage) external;
    function rebalancePlug() external;
    function transferToFactory() external;
    function tokenWant() external view returns(address);
    function tokenStrategy() external view returns(address);
    function tokenReward() external view returns(address);
    function plugTotalAmount() external view returns(uint256);
}