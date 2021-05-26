//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "../../utils/Ownable.sol";
import "./ERC1155.sol";
import "../../utils/StringLibrary.sol";

contract ERC1155Base is Ownable, ERC1155 {
    using SafeMath for uint256;
    using StringLibrary for string;

    //Token URI prefix
    string public tokenURIPrefix = 'ipfs:/';
    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    // id => creator
    mapping (uint256 => address) public creators;

    // Creates a new token type and assings _initialSupply to minter
    function _mint(uint256 _id, uint256 _supply, string memory _uri) internal {
        require(creators[_id] == address(0x0), "Token is already minted");
        require(_supply != 0, "Supply should be positive");
        require(bytes(_uri).length > 0, "uri should be set");

        creators[_id] = msg.sender;
        balances[_id][msg.sender] = _supply;
        _setTokenURI(_id, _uri);

        // Transfer event with mint semantic
        emit TransferSingle(msg.sender, address(0x0), msg.sender, _id, _supply);
        emit URI(_uri, _id);
    }

    function burn(address _owner, uint256 _id, uint256 _value) external {

        require(_owner == msg.sender || operatorApproval[_owner][msg.sender] == true, "Need operator approval for 3rd party burns.");

        // SafeMath will throw with insuficient funds _owner
        // or if _id is not valid (balance will be 0)
        balances[_id][_owner] = balances[_id][_owner].sub(_value);

        // MUST emit event
        emit TransferSingle(msg.sender, _owner, address(0x0), _id, _value);
    }

    /*
     * @dev Internal function to set the token URI for a given token.
     * Reverts if the token ID does not exist.
     * @param tokenId uint256 ID of the token to set its URI
     * @param uri string URI to assign
     */
    function _setTokenURI(uint256 tokenId, string memory _uri) internal {
        require(creators[tokenId] != address(0x0), "_setTokenURI: Token should exist");
        _tokenURIs[tokenId] = _uri;
    }

    function setTokenURIPrefix(string memory _tokenURIPrefix) public onlyOwner {
        tokenURIPrefix = _tokenURIPrefix;
    }

    function uri(uint256 tokenId) external view returns (string memory) {
        return tokenURIPrefix.append(_tokenURIs[tokenId]);
    }
}