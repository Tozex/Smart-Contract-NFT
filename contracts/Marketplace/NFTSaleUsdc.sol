pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../NFT/ICrypto4AllNFT.sol";

// SPDX-License-Identifier: GPL-3.0


contract NFTSaleUsdc is  Ownable, Pausable, ReentrancyGuard, IERC721Receiver {

  using SafeMath for uint256;
  using SafeERC20 for IERC20;
  using Address for address payable;

  event NFTSaleContractDeployed();

  event BuyNft(
    address from, 
    uint256 price, 
    uint256 tokenId
  );

  event WithdrawEth(
    address from,
    address to,
    uint256 ethBalance
  );

  event UpdateNftPrice(
    uint256 nftPrice
  );

  event UpdateIsSale(
    bool isSale
  );

  /// @notice Crypto4All NFT - the only NFT that can be offered in this contract
  ICrypto4AllNFT public crypto4AllNFT;

  /// @notice Usdc token that can be used to buy nft
  IERC20 public usdcToken;

  // Address where funds are collected
  address payable public admin;

  // Minimum purchase size of incoming ether amount, 300 USDC
  uint256 public nftPrice = 300000000;

  // Status of sale status.
  bool isSale;

  /***
   * @param _crypto4AllNFT nft contract
   * @param _usdcToken usdc contract
   * @param _admin The admin wallet
   */
  constructor(
    ICrypto4AllNFT _crypto4AllNFT,
    IERC20 _usdcToken,
    address payable _admin
  ) {
    require(_admin != address(0) && address(_crypto4AllNFT) != address(0) && address(_usdcToken) != address(0));
    admin = _admin;
    crypto4AllNFT = _crypto4AllNFT;
    usdcToken = _usdcToken;
    isSale = true;
    emit NFTSaleContractDeployed();
  }


  /**
    * @dev called by the owner to pause, triggers stopped state
    */
  function pause() public onlyOwner whenNotPaused {
      _pause();
  }

  /**
    * @dev called by the owner to unpause, returns to normal state
    */
  function unpause() public onlyOwner whenPaused {
      _unpause();
  }

  // -----------------------------------------
  // NFTSale external interface
  // -----------------------------------------


  /**
   * @dev low level token purchase ***DO NOT OVERRIDE***
   */
  function buyNft() external whenNotPaused nonReentrant {
    require(isSale, "NFTSale.buyNft: sale not enabled");
    require(crypto4AllNFT.balanceOf(address(this)) > 0, "nothing left");

    usdcToken.safeTransferFrom(msg.sender, admin, nftPrice);

    uint256 tokenId = crypto4AllNFT.tokenOfOwnerByIndex(address(this), 0);
    crypto4AllNFT.safeTransferFrom(address(this), msg.sender, tokenId);
    
    emit BuyNft(msg.sender, nftPrice, tokenId);
  }

  /* ADMINISTRATIVE FUNCTIONS */


  // Withdraw Dai amount in the contract
  function withdrawEth() external onlyOwner {
    uint256 ethBalance = address(this).balance;
    (bool transferSuccess,) = admin.call{value : ethBalance}("");
    require(transferSuccess, "ICO.withdrawEth: Failed to send ether");
    emit WithdrawEth(address(this), admin, ethBalance);
  }

  /**
    @notice Update the nftPrice
    @dev Only admin
    @param _nftPrice New price
    */
  function updateNftPrice(uint256 _nftPrice) external onlyOwner {
      nftPrice = _nftPrice;
      emit UpdateNftPrice(_nftPrice);
  }

  /**
    @notice Update the nftPrice
    @dev Only admin
    @param _isSale New price
    */
  function updateIsSale(bool _isSale) external onlyOwner {
      isSale = _isSale;
      emit UpdateIsSale(_isSale);
  }

  function onERC721Received(
      address,
      address,
      uint256,
      bytes memory
  ) public virtual override returns (bytes4) {
      return this.onERC721Received.selector;
  }

}