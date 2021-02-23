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

contract DVArtCollection is Ownable, SignerRole, ERC1155Base {
    string public name;
    string public symbol;

    constructor(string memory _name, string memory _symbol, address signer, string memory contractURI, string memory tokenURIPrefix) ERC1155Base(contractURI, tokenURIPrefix) {
        name = _name;
        symbol = _symbol;

        _addSigner(signer);
        _registerInterface(bytes4(keccak256('MINT_WITH_ADDRESS')));
    }

    function addSigner(address account) public override onlyOwner {
        _addSigner(account);
    }

    function removeSigner(address account) public onlyOwner {
        _removeSigner(account);
    }

    function mint(uint256 id, uint8 v, bytes32 r, bytes32 s, uint256 supply, string memory uri) onlyOwner public {
        require(isSigner(ecrecover(keccak256(abi.encodePacked(this, id)), v, r, s)), "signer should sign tokenId");
        _mint(id, supply, uri);
    }
}