// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import './token/ERC20.sol';
import './token/ERC20Detailed.sol';
import './token/SafeERC20.sol';

contract ISLAND is ERC20, ERC20Detailed {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint;
    
    address public governance;
    mapping (address => bool) public minters;
    
    constructor () ERC20Detailed("Defiville Island Token", "ISLA", 18) {
        governance = msg.sender;
    }
    
    function mint(address account, uint amount) public {
        require(minters[msg.sender], "!minter");
        _mint(account, amount);
    }
    
    function setGovernance(address _governance) public {
        require(msg.sender == governance, "!governance");
        governance = _governance;
    }
    
    function addMinter(address _minter) public {
        require(msg.sender == governance, "!governance");
        minters[_minter] = true;
    }
    
    function removeMinter(address _minter) public {
        require(msg.sender == governance, "!governance");
        minters[_minter] = false;
    }
}