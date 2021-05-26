pragma solidity ^0.7.6;

import "./Ownable.sol";

interface IPlugFactory {
    function registerNewPlug(address) external;
    function getUserBalance(uint256, address) external returns(uint256);
    function chargePlug(uint256, address[] memory, uint256[] memory) external;
    function dischargePlug(uint256, address[] memory, uint256[] memory) external;
    function donateToPlug(uint256, address[] memory, uint256[] memory) external;
}

interface IPLUGV2 {
    function upgradePlug(uint256) external;
    function chargePlug(address[] memory, uint256[] memory) external;
    function dischargePlug(address[] memory, uint256[] memory) external;
    function donateToPlug(address[] memory, uint256[] memory) external;
    function rebalancePlug() external;
    function getUserBalance(address) external view returns(uint256);
    //function tokenWant() external view returns(address);
    //function tokenStrategy() external view returns(address);
    //function tokenReward() external view returns(address);
}

contract PLUGRegistry is IPlugFactory, Ownable {

    event AddNewPlug(address _proxy);
    event ChargePlug(
        uint256 indexed plugId, 
        address indexed user, 
        address indexed token,
        uint256 amount
    );
    event DischargePlug(
        uint256 indexed plugId,
        address indexed user,
        address indexed token,
        uint256 amount
    );
    event DonateToPlug(
        uint256 indexed plugId,
        address indexed user,
        address indexed token,
        uint256 amount
    );
    //event ForkPlug(uint256[] plugIds);
    //event ConnectTo();

    mapping(uint256 => address) plugs;
    uint256 nextPlugId;

    function registerNewPlug(address _plugProxy) override external {
        plugs[nextPlugId] = _plugProxy;
        nextPlugId = nextPlugId + 1;
    }

    function getUserBalance(uint256 _plugId, address _user) override external view returns(uint256) {
        address plugProxy = plugs[_plugId];
        return IPLUGV2(plugProxy).getUserBalance(_user);
    }

    function chargePlug(
        uint256 _plugId, 
        address[] memory _tokens,
        uint256[] memory _amounts
    ) override external {
        _chargePlug(_plugId, _tokens, _amounts);

    }

    function _chargePlug(uint256 _plugId, address[] memory _tokens, uint256[] memory _amounts) internal {
        address plugProxy = plugs[_plugId];
        IPLUGV2(plugProxy).chargePlug(_tokens, _amounts);
    }

    function dischargePlug(
        uint256 _plugId, 
        address[] memory _tokens, 
        uint256[] memory _amounts
    ) override external {
        _dischargePlug(_plugId, _tokens, _amounts);
    }

    function _dischargePlug(
        uint256 _plugId,
        address[] memory _tokens,
        uint256[] memory _amounts
    ) internal {
        address plugProxy = plugs[_plugId];
        IPLUGV2(plugProxy).dischargePlug(_tokens, _amounts);
    }

    function donateToPlug(
        uint256 _plugId,
        address[] memory _tokens,
        uint256[] memory _amounts) override external {
            _donateToPlug(_plugId, _tokens, _amounts);
    }

    function _donateToPlug(
        uint256 _plugId, 
        address[] memory _tokens, 
        uint256[] memory _amounts
    ) internal {
        address plugProxy = plugs[_plugId];
        IPLUGV2(plugProxy).donateToPlug(_tokens, _amounts);
    }

    function pausePlug(uint256 _plugId) external {

    }
}