// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../AccessControl/Crypto4AllAccessControls.sol";
import "../NFT/ICrypto4AllNFT.sol";

/**
 * @notice Primary sale auction contract for Crypto4All NFTs
 */
contract NFTBundleAuction is Context, ReentrancyGuard {
    using SafeMath for uint256;
    using Address for address payable;

    /// @notice Event emitted only on construction. To be used by indexers
    event NFTBundleAuctionContractDeployed();

    event PauseToggled(
        bool isPaused
    );

    event AuctionCreated(
        uint256 indexed tokenId
    );

    event UpdateAuctionEndTime(
        string indexed name,
        uint256 endTime
    );

    event UpdateAuctionStartTime(
        string indexed name,
        uint256 startTime
    );

    event UpdateAuctionReservePrice(
        string indexed name,
        uint256 reservePrice
    );

    event UpdateAccessControls(
        address indexed accessControls
    );

    event UpdatePlatformFee(
        uint256 platformFee
    );

    event UpdatePlatformFeeRecipient(
        address payable platformFeeRecipient
    );

    event UpdateMinBidIncrement(
        uint256 minBidIncrement
    );

    event BidPlaced(
        string indexed name,
        address indexed bidder,
        uint256 bid
    );

    event BidWithdrawn(
        string indexed name,
        address indexed bidder,
        uint256 bid
    );

    event BidRefunded(
        address indexed bidder,
        uint256 bid
    );

    event AuctionResulted(
        string indexed name,
        address indexed winner,
        uint256 winningBid
    );

    event AuctionCancelled(
        string indexed name
    );

    /// @notice Parameters of an auction
    struct Auction {
        uint256[] tokenIds;
        uint256 reservePrice;
        uint256 startTime;
        uint256 endTime;
        bool resulted;
    }

    /// @notice Information about the sender that placed a bit on an auction
    struct HighestBid {
        address payable bidder;
        uint256 bid;
        uint256 lastBidTime;
    }

    /// @notice Bundle Name -> Auction Parameters
    mapping(string => Auction) public auctions;

    /// @notice Bundle Name -> highest bidder info (if a bid has been received)
    mapping(string => HighestBid) public highestBids;

    /// @notice NFT - the only NFT that can be auctioned in this contract
    ICrypto4AllNFT public crypto4AllNft;

    /// @notice responsible for enforcing admin access
    Crypto4AllAccessControls public accessControls;

    /// @notice globally and across all auctions, the amount by which a bid has to increase
    uint256 public minBidIncrement = 0.1 ether;

    /// @notice global platform fee, assumed to always be to 1 decimal place i.e. 20 = 2.0%
    uint256 public platformFee = 20;

    /// @notice where to send platform fee funds to
    address payable public platformFeeRecipient;

    /// @notice for switching off auction creations, bids and withdrawals
    bool public isPaused;

    modifier whenNotPaused() {
        require(!isPaused, "Function is currently paused");
        _;
    }

    constructor(
        Crypto4AllAccessControls _accessControls,
        ICrypto4AllNFT _crypto4AllNft,
        address payable _platformFeeRecipient
    ) {
        // Check inputed addresses are not zero address
        require(address(_accessControls) != address(0), "NFTBundleAuction: Invalid Access Controls");
        require(address(_crypto4AllNft) != address(0), "NFTBundleAuction: Invalid NFT");
        require(_platformFeeRecipient != address(0), "NFTBundleAuction: Invalid Platform Fee Recipient");

        accessControls = _accessControls;
        crypto4AllNft = _crypto4AllNft;
        platformFeeRecipient = _platformFeeRecipient;

        emit NFTBundleAuctionContractDeployed();
    }

    /**
     @notice Creates a new auction for a given NFT
     @dev Only the owner of a NFT can create an auction and must have approved the contract
     @dev In addition to owning the NFT, the sender also has to have the MINTER role.
     @dev End time for the auction must be in the future.
     @param _name Name of the bundle
     @param _tokenIds Token IDs of the NFT being auctioned
     @param _reservePrice NFT cannot be sold for less than this or minBidIncrement, whichever is higher
     @param _startTimestamp Unix epoch in seconds for the auction start time
     @param _endTimestamp Unix epoch in seconds for the auction end time.
     */
    function createAuction(
        string calldata _name,
        uint256[] calldata _tokenIds,
        uint256 _reservePrice,
        uint256 _startTimestamp,
        uint256 _endTimestamp
    ) external whenNotPaused {
        // Ensure caller has privileges
        require(
            accessControls.hasMinterRole(_msgSender()),
            "NFTBundleAuction.createAuction: Sender must have the minter role"
        );
        
        // Check owner of the token is the creator and approved
        for (uint256 i = 0; i < _tokenIds.length; i ++) {
            require(
                crypto4AllNft.ownerOf(_tokenIds[i]) == _msgSender() && crypto4AllNft.isApproved(_tokenIds[i], address(this)),
                "NFTBundleAuction.createAuction: Not owner and or contract not approved"
            );
        }

        _createAuction(
            _name,
            _tokenIds,
            _reservePrice,
            _startTimestamp,
            _endTimestamp
        );
    }


    /**
     @notice Places a new bid, out bidding the existing bidder if found and criteria is reached
     @dev Only callable when the auction is open
     @dev Bids from smart contracts are prohibited to prevent griefing with always reverting receiver
     @param _name Token ID of the NFT being auctioned
     */
    function placeBid(string calldata _name) external payable nonReentrant whenNotPaused {
        // require(address(_msgSender()).isContract() == false, "NFTBundleAuction.placeBid: No contracts permitted");

        // Check the auction to see if this is a valid bid
        Auction storage auction = auctions[_name];

        // Ensure auction is in flight
        require(
            _getNow() >= auction.startTime && _getNow() <= auction.endTime,
            "NFTBundleAuction.placeBid: Bidding outside of the auction window"
        );

        uint256 bidAmount = msg.value;

        // Ensure bid adheres to outbid increment and threshold
        HighestBid storage highestBid = highestBids[_name];
        uint256 minBidRequired = highestBid.bid.add(minBidIncrement);
        require(bidAmount >= minBidRequired, "NFTBundleAuction.placeBid: Failed to outbid highest bidder");

        // Refund existing top bidder if found
        if (highestBid.bidder != address(0)) {
            _refundHighestBidder(highestBid.bidder, highestBid.bid);
        }

        // assign top bidder and bid time
        highestBid.bidder = payable(_msgSender());
        highestBid.bid = bidAmount;
        highestBid.lastBidTime = _getNow();

        emit BidPlaced(_name, _msgSender(), bidAmount);
    }

    /**
     @notice Given a sender who has the highest bid on a NFT, allows them to withdraw their bid
     @dev Only callable by the existing top bidder
     @param _name Token ID of the NFT being auctioned
     */
    function withdrawBid(string calldata _name) external nonReentrant whenNotPaused {
        HighestBid storage highestBid = highestBids[_name];

        // Ensure highest bidder is the caller
        require(highestBid.bidder == _msgSender(), "NFTBundleAuction.withdrawBid: You are not the highest bidder");

        require(_getNow() < auctions[_name].endTime, "NFTBundleAuction.withdrawBid: Past auction end");

        uint256 previousBid = highestBid.bid;

        // Clean up the existing top bid
        delete highestBids[_name];

        // Refund the top bidder
        _refundHighestBidder(payable(_msgSender()), previousBid);

        emit BidWithdrawn(_name, _msgSender(), previousBid);
    }

    //////////
    // Admin /
    //////////

    /**
     @notice Results a finished auction
     @dev Only admin or smart contract
     @dev Auction can only be resulted if there has been a bidder and reserve met.
     @dev If there have been no bids, the auction needs to be cancelled instead using `cancelAuction()`
     @param _name Token ID of the NFT being auctioned
     */
    function resultAuction(string calldata _name) external nonReentrant {
        require(
            accessControls.hasAdminRole(_msgSender()),
            "NFTBundleAuction.resultAuction: Sender must be admin or smart contract"
        );

        // Check the auction to see if it can be resulted
        Auction storage auction = auctions[_name];
        
        // Check the auction real
        require(auction.endTime > 0, "NFTBundleAuction.resultAuction: Auction does not exist");

        // Check the auction has ended
        require(_getNow() > auction.endTime, "NFTBundleAuction.resultAuction: The auction has not ended");

        // Ensure auction not already resulted
        require(!auction.resulted, "NFTBundleAuction.resultAuction: auction already resulted");


        // Ensure this contract is approved to move the token
        for (uint256 i = 0; i < auction.tokenIds.length; i ++) {
            require(crypto4AllNft.isApproved(auction.tokenIds[i], address(this)), "NFTBundleAuction.resultAuction: auction not approved");
        }
        
        // Get info on who the highest bidder is
        HighestBid storage highestBid = highestBids[_name];
        address winner = highestBid.bidder;
        uint256 winningBid = highestBid.bid;
        uint256 maxShare = 1000;

        // Ensure auction not already resulted
        require(winningBid >= auction.reservePrice, "NFTBundleAuction.resultAuction: reserve not reached");

        // Ensure there is a winner
        require(winner != address(0), "NFTBundleAuction.resultAuction: no open bids");

        // Result the auction
        auctions[_name].resulted = true;

        // Clean up the highest bid
        delete highestBids[_name];

        // Work out platform fee from above reserve amount
        uint256 platformFeeInETH = winningBid.mul(platformFee).div(maxShare);

        // Send platform fee
        (bool platformTransferSuccess,) = platformFeeRecipient.call{value : platformFeeInETH}("");
        require(platformTransferSuccess, "NFTBundleAuction.resultAuction: Failed to send platform fee");

        // Send remaining to creator
        (bool creatorTransferSuccess,) = crypto4AllNft.ownerOf(auction.tokenIds[0]).call{value : winningBid.sub(platformFeeInETH)}("");
        require(creatorTransferSuccess, "NFTBundleAuction.resultAuction: Failed to send the designer their royalties");

        // Transfer the token to the winner
        for (uint256 i = 0; i < auction.tokenIds.length; i ++) {
            crypto4AllNft.safeTransferFrom(crypto4AllNft.ownerOf(auction.tokenIds[i]), winner, auction.tokenIds[i]);
        }

        emit AuctionResulted(_name, winner, winningBid);
    }

    /**
     @notice Cancels and inflight and un-resulted auctions, returning the funds to the top bidder if found
     @dev Only admin
     @param _name Token ID of the NFT being auctioned
     */
    function cancelAuction(string calldata _name) external nonReentrant {
        // Admin only resulting function
        require(
            accessControls.hasAdminRole(_msgSender()) ,
            "NFTBundleAuction.cancelAuction: Sender must be admin or smart contract"
        );

        // Check valid and not resulted
        Auction storage auction = auctions[_name];

        // Check auction is real
        require(auction.endTime > 0, "NFTBundleAuction.cancelAuction: Auction does not exist");

        // Check auction not already resulted
        require(!auction.resulted, "NFTBundleAuction.cancelAuction: auction already resulted");

        // refund existing top bidder if found
        HighestBid storage highestBid = highestBids[_name];
        if (highestBid.bidder != address(0)) {
            _refundHighestBidder(highestBid.bidder, highestBid.bid);

            // Clear up highest bid
            delete highestBids[_name];
        }

        // Remove auction and top bidder
        delete auctions[_name];

        emit AuctionCancelled(_name);
    }

    /**
     @notice Toggling the pause flag
     @dev Only admin
     */
    function toggleIsPaused() external {
        require(accessControls.hasAdminRole(_msgSender()), "NFTBundleAuction.toggleIsPaused: Sender must be admin");
        isPaused = !isPaused;
        emit PauseToggled(isPaused);
    }

    /**
     @notice Update the amount by which bids have to increase, across all auctions
     @dev Only admin
     @param _minBidIncrement New bid step in WEI
     */
    function updateMinBidIncrement(uint256 _minBidIncrement) external {
        require(accessControls.hasAdminRole(_msgSender()), "NFTBundleAuction.updateMinBidIncrement: Sender must be admin");
        minBidIncrement = _minBidIncrement;
        emit UpdateMinBidIncrement(_minBidIncrement);
    }

    /**
     @notice Update the current reserve price for an auction
     @dev Only admin
     @dev Auction must exist
     @param _name Token ID of the NFT being auctioned
     @param _reservePrice New Ether reserve price (WEI value)
     */
    function updateAuctionReservePrice(string calldata _name, uint256 _reservePrice) external {
        require(
            accessControls.hasAdminRole(_msgSender()),
            "NFTBundleAuction.updateAuctionReservePrice: Sender must be admin"
        );

        require(
            auctions[_name].endTime > 0,
            "NFTBundleAuction.updateAuctionReservePrice: No Auction exists"
        );

        auctions[_name].reservePrice = _reservePrice;
        emit UpdateAuctionReservePrice(_name, _reservePrice);
    }

    /**
     @notice Update the current start time for an auction
     @dev Only admin
     @dev Auction must exist
     @param _name Token ID of the NFT being auctioned
     @param _startTime New start time (unix epoch in seconds)
     */
    function updateAuctionStartTime(string calldata _name, uint256 _startTime) external {
        require(
            accessControls.hasAdminRole(_msgSender()),
            "NFTBundleAuction.updateAuctionStartTime: Sender must be admin"
        );

        require(
            auctions[_name].endTime > 0,
            "NFTBundleAuction.updateAuctionStartTime: No Auction exists"
        );

        auctions[_name].startTime = _startTime;
        emit UpdateAuctionStartTime(_name, _startTime);
    }

    /**
     @notice Update the current end time for an auction
     @dev Only admin
     @dev Auction must exist
     @param _name Token ID of the NFT being auctioned
     @param _endTimestamp New end time (unix epoch in seconds)
     */
    function updateAuctionEndTime(string calldata _name, uint256 _endTimestamp) external {
        require(
            accessControls.hasAdminRole(_msgSender()),
            "NFTBundleAuction.updateAuctionEndTime: Sender must be admin"
        );
        require(
            auctions[_name].endTime > 0,
            "NFTBundleAuction.updateAuctionEndTime: No Auction exists"
        );
        require(
            auctions[_name].startTime < _endTimestamp,
            "NFTBundleAuction.updateAuctionEndTime: End time must be greater than start"
        );
        require(
            _endTimestamp > _getNow(),
            "NFTBundleAuction.updateAuctionEndTime: End time passed. Nobody can bid"
        );

        auctions[_name].endTime = _endTimestamp;
        emit UpdateAuctionEndTime(_name, _endTimestamp);
    }


    /**
     @notice Method for updating the access controls contract used by the NFT
     @dev Only admin
     @param _accessControls Address of the new access controls contract (Cannot be zero address)
     */
    function updateAccessControls(Crypto4AllAccessControls _accessControls) external {
        require(
            accessControls.hasAdminRole(_msgSender()),
            "NFTBundleAuction.updateAccessControls: Sender must be admin"
        );

        require(address(_accessControls) != address(0), "NFTBundleAuction.updateAccessControls: Zero Address");

        accessControls = _accessControls;
        emit UpdateAccessControls(address(_accessControls));
    }

    /**
     @notice Method for updating platform fee
     @dev Only admin
     @param _platformFee uint256 the platform fee to set
     */
    function updatePlatformFee(uint256 _platformFee) external {
        require(
            accessControls.hasAdminRole(_msgSender()),
            "NFTBundleAuction.updatePlatformFee: Sender must be admin"
        );

        platformFee = _platformFee;
        emit UpdatePlatformFee(_platformFee);
    }

    /**
     @notice Method for updating platform fee address
     @dev Only admin
     @param _platformFeeRecipient payable address the address to sends the funds to
     */
    function updatePlatformFeeRecipient(address payable _platformFeeRecipient) external {
        require(
            accessControls.hasAdminRole(_msgSender()),
            "NFTBundleAuction.updatePlatformFeeRecipient: Sender must be admin"
        );

        require(_platformFeeRecipient != address(0), "NFTBundleAuction.updatePlatformFeeRecipient: Zero address");

        platformFeeRecipient = _platformFeeRecipient;
        emit UpdatePlatformFeeRecipient(_platformFeeRecipient);
    }

    ///////////////
    // Accessors //
    ///////////////

    /**
     @notice Method for getting all info about the auction
     @param _name Token ID of the NFT being auctioned
     */
    function getAuction(string calldata _name)
    external
    view
    returns (uint256[] memory tokenIds, uint256 _reservePrice, uint256 _startTime, uint256 _endTime, bool _resulted) {
        Auction storage auction = auctions[_name];
        return (
            auction.tokenIds,
            auction.reservePrice,
            auction.startTime,
            auction.endTime,
            auction.resulted
        );
    }

    /**
     @notice Method for getting all info about the highest bidder
     @param _name Token ID of the NFT being auctioned
     */
    function getHighestBidder(string calldata _name) external view returns (
        address payable _bidder,
        uint256 _bid,
        uint256 _lastBidTime
    ) {
        HighestBid storage highestBid = highestBids[_name];
        return (
            highestBid.bidder,
            highestBid.bid,
            highestBid.lastBidTime
        );
    }

    /////////////////////////
    // Internal and Private /
    /////////////////////////

    function _getNow() internal virtual view returns (uint256) {
        return block.timestamp;
    }

    /**
     @notice Private method doing the heavy lifting of creating an auction
     @param _name the name of bundle
     @param _tokenIds Token ID of the NFT being auctioned
     @param _reservePrice NFT cannot be sold for less than this or minBidIncrement, whichever is higher
     @param _startTimestamp Unix epoch in seconds for the auction start time
     @param _endTimestamp Unix epoch in seconds for the auction end time.
     */
    function _createAuction(
        string calldata _name,
        uint256[] calldata _tokenIds,
        uint256 _reservePrice,
        uint256 _startTimestamp,
        uint256 _endTimestamp
    ) private {
        // Ensure a token cannot be re-listed if previously successfully sold
        require(auctions[_name].endTime == 0, "NFTBundleAuction.createAuction: Cannot relist");

        // Check end time not before start time and that end is in the future
        require(_endTimestamp > _startTimestamp, "NFTBundleAuction.createAuction: End time must be greater than start");
        require(_endTimestamp > _getNow(), "NFTBundleAuction.createAuction: End time passed. Nobody can bid.");

        // Setup the auction
        auctions[_name] = Auction({
        tokenIds: _tokenIds,            
        reservePrice : _reservePrice,
        startTime : _startTimestamp,
        endTime : _endTimestamp,
        resulted : false
        });

        // emit AuctionCreated(_tokenId);
    }

    /**
     @notice Used for sending back escrowed funds from a previous bid
     @param _currentHighestBidder Address of the last highest bidder
     @param _currentHighestBid Ether amount in WEI that the bidder sent when placing their bid
     */
    function _refundHighestBidder(address payable _currentHighestBidder, uint256 _currentHighestBid) private {
        // refund previous best (if bid exists)
        (bool successRefund,) = _currentHighestBidder.call{value : _currentHighestBid}("");
        require(successRefund, "NFTBundleAuction._refundHighestBidder: failed to refund previous bidder");
        emit BidRefunded(_currentHighestBidder, _currentHighestBid);
    }
}
