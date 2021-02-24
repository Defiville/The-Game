//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "./library/math/SafeMath.sol";
import "./library/token/ERC1155/ERC1155TokenReceiver.sol";
import "./library/introspection/IERC165.sol";
import "./library/introspection/ERC165.sol";
import "./library/token/ERC1155/IERC1155.sol";
import "./library/token/ERC1155/ERC1155.sol";
import "./library/token/ERC1155/ERC1155Base.sol";
import "./library/token/ERC1155/IERC1155Metadata_URI.sol";
import "./library/token/ERC1155/ERC1155Metadata_URI.sol";
import "./library/utils/Address.sol";
import "./library/utils/CommonConstants.sol";
import "./library/utils/UintLibrary.sol";
import "./library/utils/StringLibrary.sol";
import "./library/utils/HasContractURI.sol";
import "./library/utils/HasTokenURI.sol";
import "./library/utils/Context.sol";
import "./library/access/Ownable.sol";
import "./library/utils/Roles.sol";
import "./library/utils/SignerRole.sol";

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