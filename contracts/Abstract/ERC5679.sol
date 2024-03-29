// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "../Interface/IERC5679.sol";

abstract contract ERC5679Ext20 is IERC5679Ext20, ERC165Upgradeable {
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC5679Ext20).interfaceId || super.supportsInterface(interfaceId);
    }
}

abstract contract ERC5679Ext721 is IERC5679Ext721, ERC165Upgradeable {
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC5679Ext721).interfaceId || super.supportsInterface(interfaceId);
    }
}

abstract contract ERC5679Ext1155 is IERC5679Ext1155, ERC165Upgradeable {
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC5679Ext1155).interfaceId || super.supportsInterface(interfaceId);
    }
}