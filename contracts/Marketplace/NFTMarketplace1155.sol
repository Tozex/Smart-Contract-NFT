// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../AccessControl/Crypto4AllAccessControls.sol";
import "../NFT/ICrypto4AllNFT1155.sol";
/**
 * @notice Marketplace1155 contract for Non Figgybles NFTs
 */
contract NFTMarketplace1155 is Context, ReentrancyGuard {
    using SafeMath for uint256;
    using Address for address payable;
    /// @notice Event emitted only on construction. To be used by indexers
    event NFTMarketplace1155ContractDeployed();
    event PauseToggled(
        bool isPaused
    );
    event OfferCreated(
        uint256 indexed tokenId
    );
    event UpdateAccessControls(
        address indexed accessControls
    );
    event UpdateMarketplace1155PlatformFee(
        uint256 platformFee
    );
    event UpdateMarketplace1155CreatorFee(
        uint256 creatorFee
    );
    event UpdateOfferPrimarySalePrice(
        uint256 indexed tokenId,
        uint256 primarySalePrice
    );
    event UpdatePlatformFeeRecipient(
        address payable platformFeeRecipient
    );
    event OfferPurchased(
        uint256 indexed tokenId,
        address indexed buyer,
        uint256 primarySalePrice
    );
    event OfferCancelled(
        uint256 indexed tokenId
    );
    /// @notice Parameters of a marketplace1155 offer
    struct Offer {
        address owner;
        uint256 tokenId;
        uint256 amount;
        uint256 primarySalePrice;
        uint256 startTime;
        uint256 endTime;
    }
    /// @notice List id-> Offer Parameters
    mapping(uint256 => Offer) public offers;
    /// @notice Crypto4All NFT - the only NFT that can be offered in this contract
    ICrypto4AllNFT1155 public crypto4AllNFT;
    /// @notice responsible for enforcing admin access
    Crypto4AllAccessControls public accessControls;
    /// @notice platform fee that will be sent to the platformFeeRecipient, assumed to always be to 1 decimal place i.e. 20 = 2.0%
    uint256 public platformFee = 20;
    /// @notice creator fee that will be sent to the creator of NFT
    uint256 public creatorFee = 100;
    /// @notice list id
    uint256 public listId;
    /// @notice where to send platform fee funds to
    address payable public platformFeeRecipient;
    /// @notice for pausing marketplace1155 functionalities
    bool public isPaused;

    modifier whenNotPaused() {
        require(!isPaused, "Function is currently paused");
        _;
    }
    receive() external payable {
    }   
    constructor(
        Crypto4AllAccessControls _accessControls,
        ICrypto4AllNFT1155 _crypto4AllNFT,
        address payable _platformFeeRecipient
    ) {
        require(address(_accessControls) != address(0), "NFTMarketplace1155: Invalid Access Controls");
        require(address(_crypto4AllNFT) != address(0), "NFTMarketplace1155: Invalid NFT");
        require(_platformFeeRecipient != address(0), "NFTMarketplace1155: Invalid Platform Fee Recipient");
        accessControls = _accessControls;
        crypto4AllNFT = _crypto4AllNFT;
        platformFeeRecipient = _platformFeeRecipient;

        emit NFTMarketplace1155ContractDeployed();
    }
    /**
     @notice Creates a new offer for a given Crypto4All NFT
     @dev Only the owner of a NFT can create an offer and must have ALREADY approved the contract
     @dev In addition to owning the NFT, the sender also has to have the MINTER or ADMIN role.
     @dev End time for the offer will be in the future, at a time from now till expiry duration
     @dev There cannot be a duplicate offer created
     @param _tokenId token ID of the NFT being offered to marketplace1155
     @param _amount the amount of the NFT being offered to marketplace1155
     @param _primarySalePrice NFT cannot be sold for less than this
     @param _startTimestamp Time that offer created
     @param _endTimestamp Time that offer will be finished
     */
    function createOffer(
        uint256 _tokenId,
        uint256 _amount,
        uint256 _primarySalePrice,
        uint256 _startTimestamp,
        uint256 _endTimestamp
    ) external whenNotPaused {
        // Ensure caller has privileges
        require(
            accessControls.hasMinterRole(_msgSender()) || accessControls.hasAdminRole(_msgSender()),
            "NFTMarketplace1155.createOffer: Sender must have the minter or admin role"
        );
        // Check owner of the token ID is the owner and approved
        require(
            crypto4AllNFT.balanceOf(msg.sender, _tokenId) >= _amount && crypto4AllNFT.isApprovedForAll(msg.sender, address(this)),
            "Crypto4AllNFTAuction.createOffer: Not owner and or contract not approved"
        );
        _createOffer(
            _tokenId,
            _amount,
            _primarySalePrice,
            _startTimestamp,
            _endTimestamp
        );
    }
    /**
     @notice Buys an open offer with eth
     @dev Only callable when the offer is open
     @dev Bids from smart contracts are prohibited - a user must buy directly from their address
     @dev Contract must have been approved on the buy offer previously
     @dev The sale must have started (start time) to make a successful buy
     @dev The sale must be before end time
     @param _listId token ID of the NFT being offered
     */
    function confirmOffer(uint256 _listId) external payable nonReentrant whenNotPaused {
        // Check the offers to see if this is a valid
        // require(msg.sender.isContract() == false, "NFTMarketplace1155.confirmOffer: No contracts permitted");

        Offer storage offer = offers[_listId];
        uint256 maxShare = 1000;
        // Eth amount that user deposit
        uint256 bidValue = msg.value;
        // Ensure this contract is still approved to move the token
        require(crypto4AllNFT.isApprovedForAll(offer.owner, address(this)), "NFTMarketplace1155.confirmOffer: offer not approved");
        require(_getNow() >= offer.startTime && _getNow() <= offer.endTime, "NFTMarketplace1155.confirmOffer: Purchase outside of the offer window");
        require(bidValue >= offer.primarySalePrice * offer.amount, "NFTMarketplace1155.confirmOffer: Failed to supply funds");

        // Send platform fee in ETH to the platform fee recipient
        uint256 platformFeeInETH = bidValue.mul(platformFee).div(maxShare);
        (bool platformTransferSuccess,) = platformFeeRecipient.call{value : platformFeeInETH}("");
        require(platformTransferSuccess, "NFTMarketplace1155.confirmOffer: Failed to send platform fee");

        // Send remaining to seller in ETH
        (bool sellerTransferSuccess,) = payable(offer.owner).call{value : bidValue.sub(platformFeeInETH)}("");
        require(sellerTransferSuccess, "NFTMarketplace1155.confirmOffer: Failed to send the seller their royalties");

        // Transfer the token to the purchaser
        crypto4AllNFT.safeTransferFrom(offer.owner, msg.sender, offer.tokenId, offer.amount, "");
        
        //Remove offer
        delete offers[_listId];
        emit OfferPurchased(_listId, _msgSender(), bidValue);
    }
    /**
     @notice Cancels an inflight and un-resulted offer
     @dev Only admin
     @param _tokenId Token ID of the NFT being offered
     */
    function cancelOffer(uint256 _tokenId) external nonReentrant {
        // Admin only resulting function
        require(
            accessControls.hasAdminRole(_msgSender()) || accessControls.hasMinterRole(_msgSender()),
            "NFTMarketplace1155.cancelOffer: Sender must be admin or minter contract"
        );
        // Check valid and not resulted
        Offer storage offer = offers[_tokenId];
        require(offer.primarySalePrice != 0, "NFTMarketplace1155.cancelOffer: Offer does not exist");
        require(_getNow() <= offer.endTime, "NFTMarketplace1155.cancelOffer: Offer already closed");
        // Remove offer
        delete offers[_tokenId];
        emit OfferCancelled(_tokenId);
    }

    /**
     @notice Toggling the pause flag
     @dev Only admin
     */
    function toggleIsPaused() external {
        require(accessControls.hasAdminRole(_msgSender()), "NFTMarketplace1155.toggleIsPaused: Sender must be admin");
        isPaused = !isPaused;
        emit PauseToggled(isPaused);
    }

    /**
     @notice Update the marketplace1155 fee
     @dev Only admin
     @param _platformFee New marketplace1155 fee
     */
    function updateMarketplace1155PlatformFee(uint256 _platformFee) external {
        require(accessControls.hasAdminRole(_msgSender()), "NFTMarketplace1155.updateMarketplace1155PlatformFee: Sender must be admin");
        platformFee = _platformFee;
        emit UpdateMarketplace1155PlatformFee(_platformFee);
    }

    /**
     @notice Update the creator fee
     @dev Only admin
     @param _creatorFee New creator fee
     */
    function updateMarketplace1155CreatorFee(uint256 _creatorFee) external {
        require(accessControls.hasAdminRole(_msgSender()), "NFTMarketplace1155.updateMarketplace1155CreatorFee: Sender must be admin");
        creatorFee = _creatorFee;
        emit UpdateMarketplace1155CreatorFee(_creatorFee);
    }

    /**
     @notice Update the offer primary sale price
     @dev Only admin
     @param _tokenId Token ID of the NFT being offered
     @param _primarySalePrice New price
     */
    function updateOfferPrimarySalePrice(uint256 _tokenId, uint256 _primarySalePrice) external {
        require(accessControls.hasAdminRole(_msgSender()), "NFTMarketplace1155.updateOfferPrimarySalePrice: Sender must be admin");
        
        offers[_tokenId].primarySalePrice = _primarySalePrice;
        emit UpdateOfferPrimarySalePrice(_tokenId, _primarySalePrice);
    }

    /**
     @notice Method for updating the access controls contract used by the NFT
     @dev Only admin
     @param _accessControls Address of the new access controls contract (Cannot be zero address)
     */
    function updateAccessControls(Crypto4AllAccessControls _accessControls) external {
        require(
            accessControls.hasAdminRole(_msgSender()),
            "NFTMarketplace1155.updateAccessControls: Sender must be admin"
        );
        require(address(_accessControls) != address(0), "NFTMarketplace1155.updateAccessControls: Zero Address");
        accessControls = _accessControls;
        emit UpdateAccessControls(address(_accessControls));
    }

    /**
     @notice Method for updating platform fee address
     @dev Only admin
     @param _platformFeeRecipient payable address the address to sends the funds to
     */
    function updatePlatformFeeRecipient(address payable _platformFeeRecipient) external {
        require(
            accessControls.hasAdminRole(_msgSender()),
            "NFTMarketplace1155.updatePlatformFeeRecipient: Sender must be admin"
        );
        require(_platformFeeRecipient != address(0), "NFTMarketplace1155.updatePlatformFeeRecipient: Zero address");
        platformFeeRecipient = _platformFeeRecipient;
        emit UpdatePlatformFeeRecipient(_platformFeeRecipient);
    }

    ///////////////
    // Accessors //
    ///////////////
    /**
     @notice Method for getting all info about the offer
     @param _listId Token ID of the NFT being offered
     */
    function getOffer(uint256 _listId)
    external
    view
    returns (Offer memory) {
        Offer memory offer = offers[_listId];
        return offer;
    }


    /////////////////////////
    // Internal and Private /
    /////////////////////////
    function _getNow() internal virtual view returns (uint256) {
        return block.timestamp;
    }

    /**
     @notice Private method doing the heavy lifting of creating an offer
     @param _tokenId token ID of the NFT being offered to marketplace1155
     @param _amount amount of the NFT being offered to marketplace1155
     @param _primarySalePrice NFT cannot be sold for less than this
     @param _startTimestamp Time that offer created
     @param _endTimestamp Time that offer will be finished
     */
    function _createOffer(
        uint256 _tokenId,
        uint256 _amount,
        uint256 _primarySalePrice,
        uint256 _startTimestamp,
        uint256 _endTimestamp
    ) private {
        // Ensure a token cannot be re-listed if previously successfully sold
        require(offers[++listId].startTime == 0, "NFTMarketplace1155.createOffer: Cannot duplicate current offer");
        // Setup the new offer
        offers[listId] = Offer({
            owner: msg.sender,
            tokenId: _tokenId,
            amount: _amount,
            primarySalePrice : _primarySalePrice,
            startTime : _startTimestamp,
            endTime : _endTimestamp
        });
        emit OfferCreated(listId);
    }

    /**
     * @notice Reclaims ETH, drains all ETH sitting on the smart contract
     * @dev The instant buy feature means technically, ETH should never sit on contract.
     * @dev Only access controls admin can access
     */
    function reclaimETH() external {
        require(
            accessControls.hasAdminRole(_msgSender()),
            "NFTMarketplace1155.reclaimETH: Sender must be admin"
        );
        (bool transferSuccess,) = msg.sender.call{value : address(this).balance }("");
        require(transferSuccess, "NFTMarketplace1155.reclaimETH: Failed to send eth");
    }
}