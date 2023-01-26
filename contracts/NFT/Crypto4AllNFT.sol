// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Consecutive.sol";
import "../AccessControl/Crypto4AllAccessControls.sol";
import "../Abstract/ERC5679.sol";


/**
 * @title Crypto4All  NFT
 * @dev Issues ERC-721 tokens 
 */
contract Crypto4AllNFT is ERC5679Ext721, ERC721Consecutive {
    using SafeMath for uint256;

    /// @notice event emitted upon construction of this contract, used to bootstrap external indexers
    event Crypto4AllNFTContractDeployed();

    /// @notice event emitted when royalty percent is updated
    event SetRoyaltyPercent(
        uint256 royaltyPercent
    );

    /// @notice event emitted when token URI is updated
    event Crypto4AllTokenUriUpdate(
        uint256 indexed _tokenId,
        string _tokenUri
    );    

    /// @dev Required to govern who can call certain functions
    Crypto4AllAccessControls public accessControls;

    /// @dev the percent of royalty
    uint256 public royaltyPercent;

    /// @dev current max tokenId
    uint256 public totalSupply;

    /// @dev base uri
    string private _baseURIString;

    /**
     * @notice Constructor
     * @param _accessControls Address of the Crypto4AllNFT access control contract
     * @param _name Name of the NFT
     * @param _symbol Symbol of nft
     */
    constructor(
        Crypto4AllAccessControls _accessControls,
        string memory _name,
        string memory _symbol,
        string memory uri_,
        address _recipient,
        uint96 _totalSupply,
        uint256 _royaltyPercent
    ) ERC721(_name, _symbol) {
        accessControls = _accessControls;
        royaltyPercent = _royaltyPercent;
        _baseURIString = uri_;

        totalSupply = _totalSupply;

        _mintConsecutive(_recipient, _totalSupply);
        
        emit Crypto4AllNFTContractDeployed();
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, it can be overridden in child contracts.
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseURIString;
    }

    /**
     * @notice Mints a Crypto4AllNFT AND when minting to a contract checks if the beneficiary is a 721 compatible
     * @dev Only senders with either the admin or mintor role can invoke this method
     * @param _to Recipient of the NFT
     * @param _id Token id of NFT
     */
    function safeMint(
        address _to,
        uint256 _id,
        bytes calldata // _data (unused)
    ) external override {
        require(
            accessControls.hasAdminRole(_msgSender()) || accessControls.hasMinterRole(_msgSender()),
            "Crypto4AllNFT.mint: Sender must have the admin or minter role"
        );

        require(_id == totalSupply, "Invalid token id");

        // Mint token and set token URI
        _safeMint(_to, _id);
    }

    /**
     * @notice Burn a Crypto4AllNFT 
     * @dev Only owner of nft can call this function
     * @param _id Token id of NFT
     */
    function burn(
        address, // _from, (unused)
        uint256 _id,
        bytes calldata // _data (unused)
    ) external override {
        require(
            ownerOf(_id) == msg.sender, 
            "Only nft owner can burn the nft"
        );

        // Burn token
        _burn(_id); 
    }


    //////////
    // Admin /
    //////////

    /**
     * @notice Updates the percent of royalty
     * @dev Only admin
     * @param _royaltyPercent The ID of the token being updated
     */
    function setRoyaltyPercent(uint256 _royaltyPercent) external {
        require(
            accessControls.hasAdminRole(_msgSender()),"Crypto4AllNFT.setRoyaltyPercent: Sender must have the admin role"
        );
        royaltyPercent = _royaltyPercent;
        emit SetRoyaltyPercent(_royaltyPercent);
    }

    /**
     * @notice Method for updating the access controls contract used by the NFT
     * @dev Only admin
     * @param _accessControls Address of the new access controls contract
     */
    function updateAccessControls(Crypto4AllAccessControls _accessControls) external {
        require(accessControls.hasAdminRole(_msgSender()), "Crypto4AllNFT.updateAccessControls: Sender must be admin");
        accessControls = _accessControls;
    }
    /////////////////
    // View Methods /
    /////////////////

    /**
     * @notice View method for checking whether a token has been minted
     * @param _tokenId ID of the token being checked
     */
    function exists(uint256 _tokenId) external view returns (bool) {
        return _exists(_tokenId);
    }

    /**
     * @dev checks the given token ID is approved either for all or the single token ID
     */
    function isApproved(uint256 _tokenId, address _operator) public view returns (bool) {
        return isApprovedForAll(ownerOf(_tokenId), _operator) || getApproved(_tokenId) == _operator;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC5679Ext721, ERC721)
        returns (bool)
    {}
}
