// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../Marketplace/NFTMarketplace.sol";

contract NFTMarketplaceMock is NFTMarketplace {
    uint256 public nowOverride;

    constructor(
        Crypto4AllAccessControls _accessControls,
        ICrypto4AllNFT _crypto4AllNFT,
        address payable _platformFeeRecipient
    ) NFTMarketplace(_accessControls, _crypto4AllNFT, _platformFeeRecipient) {}

    function setNowOverride(uint256 _now) external {
        nowOverride = _now;
    }

    function _getNow() internal override view returns (uint256) {
        return nowOverride;
    }
}
