// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "../AccessControl/Crypto4AllAccessControls.sol";
import "./NFT.sol";

/**
 * @title Crypto4All  NFT
 * @dev Issues ERC-721 tokens 
 */
contract Crypto4AllNFT is IERC2981, ERC721 {
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
    uint256 public tokenIdPointer;

    /// @dev TokenID -> Post Creator address
    mapping(uint256 => address) public postCreators;

    /**
     @notice Constructor
     @param _accessControls Address of the Crypto4AllNFT access control contract
     @param _name Name of the NFT
     @param _symbol Symbol of nft
     */
    constructor(
        Crypto4AllAccessControls _accessControls,
        string memory _name,
        string memory _symbol,
        uint256 _royaltyPercent
    ) ERC721(_name, _symbol) {
        accessControls = _accessControls;
        royaltyPercent = _royaltyPercent;
        emit Crypto4AllNFTContractDeployed();
    }

    /**
     @notice Mints a Crypto4AllNFT AND when minting to a contract checks if the beneficiary is a 721 compatible
     @dev Only senders with either the admin or mintor role can invoke this method
     @param _beneficiary Recipient of the NFT
     @param _tokenUri URI for the token being minted
     @param _postCreator NFT Creator - will be required for issuing royalties from secondary sales
     @return uint256 The token ID of the token that was minted
     */
    function mint(address _beneficiary, string calldata _tokenUri, address _postCreator) external returns (uint256) {
        require(
            accessControls.hasAdminRole(_msgSender()) || accessControls.hasMinterRole(_msgSender()),
            "Crypto4AllNFT.mint: Sender must have the admin or minter role"
        );
        // Valid args
        _assertMintingParamsValid(_tokenUri, _postCreator);

        tokenIdPointer = tokenIdPointer + 1;
        uint256 tokenId = tokenIdPointer;

        // Mint token and set token URI
        _safeMint(_beneficiary, tokenId);
        _setTokenURI(tokenId, _tokenUri);

        postCreators[tokenId] = _postCreator;

        return tokenId;
    }


    /**
     @notice Mints a Crypto4AllNFT AND when minting to a contract checks if the beneficiary is a 721 compatible
     @dev Only senders with either the admin or mintor role can invoke this method
     @param _beneficiary Recipient of the NFT
     @param _count the Number of token uri
     @param _tokenUri URI for the token being minted
     @param _postCreator NFT Creator - will be required for issuing royalties from secondary sales
     */
    function mintMany(address _beneficiary, uint256 _count, string calldata _tokenUri, address _postCreator) external {
        require(
            accessControls.hasAdminRole(_msgSender()) || accessControls.hasMinterRole(_msgSender()),
            "Crypto4AllNFT.mint: Sender must have the admin or minter role"
        );

        uint256 fromTokenId = tokenIdPointer + 1;
        uint256 toTokenId = tokenIdPointer + _count;

        // Mint token and set token URI
        _safeMintMany(_beneficiary, fromTokenId, toTokenId);

        for(uint256 i = 0; i < _count; i ++) {
            // Valid args
            uint256 tokenId = tokenIdPointer + i + 1;
            _assertMintingParamsValid(_tokenUri, _postCreator);
            _setTokenURI(tokenId, _tokenUri);

            postCreators[tokenId] = _postCreator;
        }
        tokenIdPointer = tokenIdPointer + _count;
    }
    //////////
    // Admin /
    //////////

    /**
     @notice Updates the percent of royalty
     @dev Only admin
     @param _royaltyPercent The ID of the token being updated
     */
    function setRoyaltyPercent(uint256 _royaltyPercent) external {
        require(
            accessControls.hasAdminRole(_msgSender()),"Crypto4AllNFT.setRoyaltyPercent: Sender must have the admin role"
        );
        royaltyPercent = _royaltyPercent;
        emit SetRoyaltyPercent(_royaltyPercent);
    }

    /**
     @notice Updates the token URI of a given token
     @dev Only admin
     @param _tokenId The ID of the token being updated
     @param _tokenUri The new URI
     */
    function setTokenURI(uint256 _tokenId, string calldata _tokenUri) external {
        require(
            accessControls.hasAdminRole(_msgSender()),"Crypto4AllNFT.setTokenURI: Sender must have the admin role"
        );
        _setTokenURI(_tokenId, _tokenUri);
        emit Crypto4AllTokenUriUpdate(_tokenId, _tokenUri);
    }

    /**
     @notice Method for updating the access controls contract used by the NFT
     @dev Only admin
     @param _accessControls Address of the new access controls contract
     */
    function updateAccessControls(Crypto4AllAccessControls _accessControls) external {
        require(accessControls.hasAdminRole(_msgSender()), "Crypto4AllNFT.updateAccessControls: Sender must be admin");
        accessControls = _accessControls;
    }
    /////////////////
    // View Methods /
    /////////////////

    /**
     * @dev See {IERC2981-royaltyInfo}.
     */

    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view override(IERC2981) returns (address receiver, uint256 royaltyAmount) {
        receiver = postCreators[tokenId];
        royaltyAmount = salePrice.mul(royaltyPercent).div(10000);
    }

    /**
     @notice View method for checking whether a token has been minted
     @param _tokenId ID of the token being checked
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

    /////////////////////////
    // Internal and Private /
    /////////////////////////

    /**
     @notice Checks that the URI is not empty and the post creator is a real address
     @param _tokenUri URI supplied on minting
     @param _postCreator Address supplied on minting
     */
    function _assertMintingParamsValid(string calldata _tokenUri, address _postCreator) pure internal {
        require(bytes(_tokenUri).length > 0, "Crypto4AllNFT._assertMintingParamsValid: Token URI is empty");
        require(_postCreator != address(0), "Crypto4AllNFT._assertMintingParamsValid: creator is zero address");
    }
}
