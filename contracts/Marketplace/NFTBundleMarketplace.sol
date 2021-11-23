// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../AccessControl/Crypto4AllAccessControls.sol";
import "../NFT/ICrypto4AllNFT.sol";
/**
 * @notice Marketplace contract for Non Figgybles NFTs
 */
contract NFTBundleMarketplace is Context, ReentrancyGuard {
    using SafeMath for uint256;
    using Address for address payable;
    /// @notice Event emitted only on construction. To be used by indexers
    event NFTBundleMarketplaceContractDeployed();
    event PauseToggled(
        bool isPaused
    );
    event OfferCreated(
        string indexed name
    );
    event UpdateAccessControls(
        address indexed accessControls
    );
    event UpdateMarketplacePlatformFee(
        uint256 platformFee
    );
    event UpdateMarketplaceCreatorFee(
        uint256 creatorFee
    );
    event UpdateOfferPrimarySalePrice(
        string indexed name,
        uint256 primarySalePrice
    );
    event UpdatePlatformFeeRecipient(
        address payable platformFeeRecipient
    );
    event OfferPurchased(
        string indexed name,
        address indexed buyer,
        uint256 primarySalePrice
    );
    event OfferCancelled(
        string indexed name
    );
    /// @notice Parameters of a marketplace offer
    struct Offer {
        uint256[] tokenIds;
        uint256 primarySalePrice;
        uint256 startTime;
        uint256 endTime;
    }
    /// @notice Bundle name -> Offer Parameters
    mapping(string => Offer) public offers;

    /// @notice Crypto4All NFT - the only NFT that can be offered in this contract
    ICrypto4AllNFT public crypto4AllNFT;
    /// @notice responsible for enforcing admin access
    Crypto4AllAccessControls public accessControls;
    /// @notice platform fee that will be sent to the platformFeeRecipient, assumed to always be to 1 decimal place i.e. 20 = 2.0%
    uint256 public platformFee = 20;
    /// @notice creator fee that will be sent to the creator of NFT
    uint256 public creatorFee = 100;
    /// @notice where to send platform fee funds to
    address payable public platformFeeRecipient;
    /// @notice for pausing marketplace functionalities
    bool public isPaused;

    modifier whenNotPaused() {
        require(!isPaused, "Function is currently paused");
        _;
    }
    receive() external payable {
    }   
    constructor(
        Crypto4AllAccessControls _accessControls,
        ICrypto4AllNFT _crypto4AllNFT,
        address payable _platformFeeRecipient
    ) {
        require(address(_accessControls) != address(0), "NFTBundleMarketplace: Invalid Access Controls");
        require(address(_crypto4AllNFT) != address(0), "NFTBundleMarketplace: Invalid NFT");
        require(_platformFeeRecipient != address(0), "NFTBundleMarketplace: Invalid Platform Fee Recipient");
        accessControls = _accessControls;
        crypto4AllNFT = _crypto4AllNFT;
        platformFeeRecipient = _platformFeeRecipient;

        emit NFTBundleMarketplaceContractDeployed();
    }
    /**
     @notice Creates a new offer for a given Crypto4All NFT
     @dev Only the owner of a NFT can create an offer and must have ALREADY approved the contract
     @dev In addition to owning the NFT, the sender also has to have the MINTER or ADMIN role.
     @dev End time for the offer will be in the future, at a time from now till expiry duration
     @dev There cannot be a duplicate offer created
     @param _name token ID of the NFT being offered to marketplace
     @param _primarySalePrice NFT cannot be sold for less than this
     @param _startTimestamp Time that offer created
     @param _endTimestamp Time that offer will be finished
     */
    function createOffer(
        string calldata _name,
        uint256[] calldata _tokenIds,
        uint256 _primarySalePrice,
        uint256 _startTimestamp,
        uint256 _endTimestamp
    ) external whenNotPaused {
        // Ensure caller has privileges
        require(
            accessControls.hasMinterRole(_msgSender()) || accessControls.hasAdminRole(_msgSender()),
            "NFTBundleMarketplace.createOffer: Sender must have the minter or admin role"
        );
        for (uint256 i = 0; i < _tokenIds.length; i ++) {

            // Ensure the token ID does exists
            require(crypto4AllNFT.exists(_tokenIds[i]), "NFTBundleMarketplace.createOffer: TokenID does not exist");
            // Check owner of the token ID is the owner and approved
            require(
                crypto4AllNFT.ownerOf(_tokenIds[i]) == _msgSender() && crypto4AllNFT.isApproved(_tokenIds[i], address(this)),
                "Crypto4AllNFTAuction.createOffer: Not owner and or contract not approved"
            );
        }
        _createOffer(
            _name,
            _tokenIds,
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
     @param _name token ID of the NFT being offered
     */
    function confirmOffer(string calldata _name) external payable nonReentrant whenNotPaused {
        // Check the offers to see if this is a valid
        // require(msg.sender.isContract() == false, "NFTBundleMarketplace.confirmOffer: No contracts permitted");

        Offer storage offer = offers[_name];
        uint256 maxShare = 1000;
        // Eth amount that user deposit
        uint256 bidValue = msg.value;
        // Ensure this contract is still approved to move the token
        for (uint256 i = 0; i < offer.tokenIds.length; i ++) {
            require(crypto4AllNFT.isApproved(offer.tokenIds[i], address(this)), "NFTBundleMarketplace.confirmOffer: offer not approved");
        }

        require(_getNow() >= offer.startTime && _getNow() <= offer.endTime, "NFTBundleMarketplace.confirmOffer: Purchase outside of the offer window");
        require(bidValue >= offer.primarySalePrice, "NFTBundleMarketplace.confirmOffer: Failed to supply funds");

        // Send platform fee in ETH to the platform fee recipient
        uint256 platformFeeInETH = bidValue.mul(platformFee).div(maxShare);
        (bool platformTransferSuccess,) = platformFeeRecipient.call{value : platformFeeInETH}("");
        require(platformTransferSuccess, "NFTBundleMarketplace.confirmOffer: Failed to send platform fee");

        // Send remaining to seller in ETH
        (bool sellerTransferSuccess,) = crypto4AllNFT.ownerOf(offer.tokenIds[0]).call{value : bidValue.sub(platformFeeInETH)}("");
        require(sellerTransferSuccess, "NFTBundleMarketplace.confirmOffer: Failed to send the seller their royalties");


        // Transfer the token to the purchaser
        for (uint256 i = 0; i < offer.tokenIds.length; i ++) {
            crypto4AllNFT.safeTransferFrom(crypto4AllNFT.ownerOf(offer.tokenIds[i]), msg.sender, offer.tokenIds[i]);
        }
        
        //Remove offer
        delete offers[_name];
        emit OfferPurchased(_name, _msgSender(), bidValue);
    }
    /**
     @notice Cancels an inflight and un-resulted offer
     @dev Only admin
     @param _name Token ID of the NFT being offered
     */
    function cancelOffer(string calldata _name) external nonReentrant {
        // Admin only resulting function
        require(
            accessControls.hasAdminRole(_msgSender()) || accessControls.hasMinterRole(_msgSender()),
            "NFTBundleMarketplace.cancelOffer: Sender must be admin or minter contract"
        );
        // Check valid and not resulted
        Offer storage offer = offers[_name];
        require(offer.primarySalePrice != 0, "NFTBundleMarketplace.cancelOffer: Offer does not exist");
        require(_getNow() <= offer.endTime, "NFTBundleMarketplace.cancelOffer: Offer already closed");
        // Remove offer
        delete offers[_name];
        emit OfferCancelled(_name);
    }

    /**
     @notice Toggling the pause flag
     @dev Only admin
     */
    function toggleIsPaused() external {
        require(accessControls.hasAdminRole(_msgSender()), "NFTBundleMarketplace.toggleIsPaused: Sender must be admin");
        isPaused = !isPaused;
        emit PauseToggled(isPaused);
    }

    /**
     @notice Update the marketplace fee
     @dev Only admin
     @param _platformFee New marketplace fee
     */
    function updateMarketplacePlatformFee(uint256 _platformFee) external {
        require(accessControls.hasAdminRole(_msgSender()), "NFTBundleMarketplace.updateMarketplacePlatformFee: Sender must be admin");
        platformFee = _platformFee;
        emit UpdateMarketplacePlatformFee(_platformFee);
    }

    /**
     @notice Update the creator fee
     @dev Only admin
     @param _creatorFee New creator fee
     */
    function updateMarketplaceCreatorFee(uint256 _creatorFee) external {
        require(accessControls.hasAdminRole(_msgSender()), "NFTBundleMarketplace.updateMarketplaceCreatorFee: Sender must be admin");
        creatorFee = _creatorFee;
        emit UpdateMarketplaceCreatorFee(_creatorFee);
    }

    /**
     @notice Update the offer primary sale price
     @dev Only admin
     @param _name Token ID of the NFT being offered
     @param _primarySalePrice New price
     */
    function updateOfferPrimarySalePrice(string calldata _name, uint256 _primarySalePrice) external {
        require(accessControls.hasAdminRole(_msgSender()), "NFTBundleMarketplace.updateOfferPrimarySalePrice: Sender must be admin");
        
        offers[_name].primarySalePrice = _primarySalePrice;
        emit UpdateOfferPrimarySalePrice(_name, _primarySalePrice);
    }

    /**
     @notice Method for updating the access controls contract used by the NFT
     @dev Only admin
     @param _accessControls Address of the new access controls contract (Cannot be zero address)
     */
    function updateAccessControls(Crypto4AllAccessControls _accessControls) external {
        require(
            accessControls.hasAdminRole(_msgSender()),
            "NFTBundleMarketplace.updateAccessControls: Sender must be admin"
        );
        require(address(_accessControls) != address(0), "NFTBundleMarketplace.updateAccessControls: Zero Address");
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
            "NFTBundleMarketplace.updatePlatformFeeRecipient: Sender must be admin"
        );
        require(_platformFeeRecipient != address(0), "NFTBundleMarketplace.updatePlatformFeeRecipient: Zero address");
        platformFeeRecipient = _platformFeeRecipient;
        emit UpdatePlatformFeeRecipient(_platformFeeRecipient);
    }

    ///////////////
    // Accessors //
    ///////////////
    /**
     @notice Method for getting all info about the offer
     @param _name Token ID of the NFT being offered
     */
    function getOffer(string calldata _name)
    external
    view
    returns (uint256[] memory _tokenIds, uint256 _primarySalePrice, uint256 _startTime, uint256 _endTime) {
        Offer storage offer = offers[_name];
        return (
            offer.tokenIds,
            offer.primarySalePrice,
            offer.startTime,
            offer.endTime
        );
    }


    /////////////////////////
    // Internal and Private /
    /////////////////////////
    function _getNow() internal virtual view returns (uint256) {
        return block.timestamp;
    }

    /**
     @notice Private method doing the heavy lifting of creating an offer
     @param _name The name of the bundle
     @param _tokenIds token ID of the NFT being offered to marketplace
     @param _primarySalePrice NFT cannot be sold for less than this
     @param _startTimestamp Time that offer created
     @param _endTimestamp Time that offer will be finished
     */
    function _createOffer(
        string calldata _name,
        uint256[] calldata _tokenIds,
        uint256 _primarySalePrice,
        uint256 _startTimestamp,
        uint256 _endTimestamp
    ) private {
        // Ensure a token cannot be re-listed if previously successfully sold
        require(offers[_name].startTime == 0, "NFTBundleMarketplace.createOffer: Cannot duplicate current offer");
        // Setup the new offer
        offers[_name] = Offer({
            tokenIds : _tokenIds,
            primarySalePrice : _primarySalePrice,
            startTime : _startTimestamp,
            endTime : _endTimestamp
        });
        emit OfferCreated(_name);
    }

    /**
     * @notice Reclaims ETH, drains all ETH sitting on the smart contract
     * @dev The instant buy feature means technically, ETH should never sit on contract.
     * @dev Only access controls admin can access
     */
    function reclaimETH() external {
        require(
            accessControls.hasAdminRole(_msgSender()),
            "NFTBundleMarketplace.reclaimETH: Sender must be admin"
        );
        (bool transferSuccess,) = msg.sender.call{value : address(this).balance }("");
        require(transferSuccess, "NFTBundleMarketplace.reclaimETH: Failed to send eth");
    }
}