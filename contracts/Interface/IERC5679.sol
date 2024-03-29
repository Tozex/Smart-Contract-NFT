// SPDX-License-Identifier: Apache-2.0
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";

pragma solidity ^0.8.0;

interface IERC5679Ext20 {
   function mint(address _to, uint256 _amount, bytes calldata _data) external;
   function burn(address _from, uint256 _amount, bytes calldata _data) external;
}

interface IERC5679Ext721 {
   function safeMint(address _to, uint256 _id, bytes calldata _data) external payable;
   function burn(address _from, uint256 _id, bytes calldata _data) external;
}

interface IERC5679Ext1155 {
   function safeMint(address _to, uint256 _id, uint256 _amount, bytes calldata _data) external;
   function safeMintBatch(address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external;
   function burn(address _from, uint256 _id, uint256 _amount, bytes calldata _data) external;
   function burnBatch(address _from, uint256[] calldata ids, uint256[] calldata amounts, bytes[] calldata _data) external;
}