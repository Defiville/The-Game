// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "./ERC1155Receiver.sol";

/**
 * @dev _Available since v3.1._
 */
abstract contract ERC1155Holder is ERC1155Receiver {
    /**
     * @dev See {IERC1155Receiver-onERC1155Received}.
     *
     * Always returns `IERC1155Receiver.onERC1155Received.selector`.
     */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /**
     * @dev See {IERC1155BatchReceiver-onERC1155BatchReceived}.
     *
     * Always returns `IERC1155BatchReceiver.onERC1155BatchReceived.selector`.
     */
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}