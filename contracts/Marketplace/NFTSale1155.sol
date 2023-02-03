pragma solidity ^0.8.1;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../NFT/ICrypto4AllNFT1155.sol";

// SPDX-License-Identifier: GPL-3.0


contract NFTSale is  Ownable, Pausable, ReentrancyGuard, ERC1155HolderUpgradeable {

  using SafeMath for uint256;
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
  ICrypto4AllNFT1155 public crypto4AllNFT;

  // Address where funds are collected
  address payable public admin;

  // Minimum purchase size of incoming ether amount
  uint256 public nftPrice = 0.0001 ether;

  // Token id for sale
  uint256 public saleTokenId;

  // Status of sale status.
  bool isSale;

  /***
   * @param _accessControls accesscontrols contract
   * @param _crypto4AllNFT nft contract
   * @param _admin The admin wallet
   */
  constructor(
    ICrypto4AllNFT1155 _crypto4AllNFT,
    address payable _admin
  ) {
    require(_admin != address(0) && address(_crypto4AllNFT) != address(0));
    admin = _admin;
    crypto4AllNFT = _crypto4AllNFT;
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
  receive() external payable {
    buyNft();
  }


  /**
   * @dev low level token purchase ***DO NOT OVERRIDE***
   */
  function buyNft() internal whenNotPaused nonReentrant {
    require(isSale, "NFTSale.buyNft: sale not enabled");
    require(msg.value >= nftPrice, "NFTSale.buyNft: amount not same");
    require(crypto4AllNFT.balanceOf(address(this), saleTokenId) > 0, "nothing left");


    (bool transferSuccess,) = admin.call{value : msg.value}("");
    require(transferSuccess, "NFTSale.buyNft: Failed to send deposit ether");

    crypto4AllNFT.safeTransferFrom(address(this), msg.sender, saleTokenId, 1, "");
    
    emit BuyNft(msg.sender, msg.value, saleTokenId);
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

  /**
    @notice Update the nftPrice
    @dev Only admin
    @param _saleTokenId New price
    */
  function updateSaleTokenId(uint256 _saleTokenId) external onlyOwner {
      saleTokenId = _saleTokenId;
  }

}