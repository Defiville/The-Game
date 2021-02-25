//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "./library/token/ERC1155/ERC1155Base.sol";

contract DVArtist is ERC1155Base {
    string public name;
    string public symbol;

    constructor() {
        name = "Defiville Artist Collection";
        symbol = "DVART";
    }

    function mint(uint256 id, uint256 supply, string memory uri) onlyOwner public {
        _mint(id, supply, uri);
    }
}