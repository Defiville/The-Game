//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "./library/token/ERC1155/ERC1155Base.sol";

contract DVArtist is Ownable, ERC1155Base {
    string public name;
    string public symbol;

    constructor(string memory _name, string memory _symbol, string memory tokenURIPrefix) ERC1155Base(tokenURIPrefix) {
        name = _name;
        symbol = _symbol;
    }

    function mint(uint256 id, uint256 supply, string memory uri) onlyOwner public {
        _mint(id, supply, uri);
    }
}