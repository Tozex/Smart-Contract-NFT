// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../Marketplace/NFTAuction.sol";

contract NFTAuctionMock is NFTAuction {
    uint256 public nowOverride;

    constructor(
        Crypto4AllAccessControls _accessControls,
        ICrypto4AllNFT _crypto4AllNft,
        address payable _platformFeeRecipient
    ) NFTAuction(_accessControls, _crypto4AllNft, _platformFeeRecipient){}

    function setNowOverride(uint256 _now) external {
        nowOverride = _now;
    }

    function _getNow() internal override view returns (uint256) {
        return nowOverride;
    }
}
