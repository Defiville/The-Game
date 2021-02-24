//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "./IERC1155Metadata_URI.sol";
import "../../utils/HasTokenURI.sol";

/**
    Note: The ERC-165 identifier for this interface is 0x0e89341c.
*/
contract ERC1155Metadata_URI is IERC1155Metadata_URI, HasTokenURI {

    constructor(string memory _tokenURIPrefix) HasTokenURI(_tokenURIPrefix) {

    }

    function uri(uint256 _id) external view override returns (string memory) {
        return _tokenURI(_id);
    }
}