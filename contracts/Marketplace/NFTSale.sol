pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "../NFT/ICrypto4AllNFT.sol";

// SPDX-License-Identifier: GPL-3.0


contract NFTSale is  Ownable, Pausable, ReentrancyGuard, IERC721Receiver {

  using SafeMath for uint256;
  using Address for address payable;

  enum SalesStatus {
    Pause,
    Allowlist,
    Public
  }
    
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
    SalesStatus salesStatus
  );

  // Status of sale status.
  SalesStatus public salesStatus;

  /// @notice Crypto4All NFT - the only NFT that can be offered in this contract
  ICrypto4AllNFT public crypto4AllNFT;

  /// @notice Flags for allowlist minting.
  mapping(address => bool) public allowlistMinted;

  // Address where funds are collected
  address payable public admin;

  // Minimum purchase size of incoming ether amount
  uint256 public nftPrice = 0.0001 ether;

  /// @dev Hash of merkle tree root, which is used for allowlist proof.
  bytes32 private _merkleRoot;
  
  /***
   * @param _accessControls accesscontrols contract
   * @param _crypto4AllNFT nft contract
   * @param _admin The admin wallet
   * @param merkleRoot_ The hash of root of the merkle tree for allowlist mint.
   */
  constructor(
    ICrypto4AllNFT _crypto4AllNFT,
    address payable _admin,
    bytes32 merkleRoot_
  ) {
    require(_admin != address(0) && address(_crypto4AllNFT) != address(0));

    admin = _admin;
    crypto4AllNFT = _crypto4AllNFT;
    salesStatus = SalesStatus.Pause;

    _merkleRoot = merkleRoot_;
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
  // receive() external payable {
  //   require(salesStatus == SalesStatus.Public, "NFTSale.buyNft: sale not enabled");
  //   buyNft();
  // }


  /**
   * @dev low level token purchase ***DO NOT OVERRIDE***
   */
  function buyNft(bytes32[] calldata merkleProof) external payable whenNotPaused nonReentrant {
    require(salesStatus != SalesStatus.Pause, "NFTSale.buyNft: sale not enabled");
    require(msg.value >= nftPrice, "NFTSale.buyNft: amount not same");
    require(crypto4AllNFT.balanceOf(address(this)) > 0, "nothing left");

    if (salesStatus == SalesStatus.Allowlist) {
      require(allowlistMinted[msg.sender] == false, "You've already minted");

      // Verify Merkle Tree
      bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
      require(
          MerkleProof.verify(merkleProof, _merkleRoot, leaf),
          "Not allowlisted"
      );

      allowlistMinted[msg.sender] == true;
    }

    (bool transferSuccess,) = admin.call{value : msg.value}("");
    require(transferSuccess, "NFTSale.buyNft: Failed to send deposit ether");

    uint256 tokenId = crypto4AllNFT.tokenOfOwnerByIndex(address(this), 0);
    crypto4AllNFT.safeTransferFrom(address(this), msg.sender, tokenId);
    
    emit BuyNft(msg.sender, msg.value, tokenId);
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
    @param _nftPrice New pricex
    */
  function updateNftPrice(uint256 _nftPrice) external onlyOwner {
      nftPrice = _nftPrice;
      emit UpdateNftPrice(_nftPrice);
  }

  /**
    @notice Update the nftPrice
    @dev Only admin
    @param _salesStatus New price
    */
  function updateIsSale(SalesStatus _salesStatus) external onlyOwner {
      salesStatus = _salesStatus;
      emit UpdateIsSale(_salesStatus);
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