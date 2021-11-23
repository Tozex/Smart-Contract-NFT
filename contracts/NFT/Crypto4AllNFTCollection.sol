// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../AccessControl/Crypto4AllAccessControls.sol";
import "./ICrypto4AllNFT.sol";

/**
 * @notice Collection contract for Digitalax NFTs
 */
contract Crypto4AllNFTCollection is Context, ReentrancyGuard {
    using SafeMath for uint256;
    using Address for address payable;

    /// @notice Event emitted only on construction. To be used by indexers
    event Crypto4AllNFTCollectionContractDeployed();
    event MintGarmentCollection(
        address beneficiary,
        string tokenUri,
        address designer,
        uint256 amount
    );
    event BurnGarmentCollection(
        uint256 collectionId
    );
    event AddNftToCollection(
        uint256 collectionId,
        uint256[] tokenIds, 
        uint256[] tokenPrices
    );
    event RemoveNftFromCollection(
        uint256 collectionId, 
        uint256[] tokenIds
    );

    /// @notice Parameters of a NFTs Collection
    struct Collection {
        string name;
        string metadata;
        uint256[] nftTokenIds;
        address creator;
        mapping(uint256 => uint256) indexPerTokenId;
        mapping(uint256 => uint256) pricePerTokenId;
    }

    /// @notice Garment ERC721 NFT - the only NFT that can be offered in this contract
    ICrypto4AllNFT public crypto4AllNft;
    /// @notice responsible for enforcing admin access
    Crypto4AllAccessControls public accessControls;
    /// @notice Array of nft collections
    
    uint256 public numCollection;
    mapping(uint256 => Collection) public nftCollection;


    /**
     @param _accessControls Address of the Digitalax access control contract
     @param _crypto4AllNft  NFT token address
     */
    constructor(
        Crypto4AllAccessControls _accessControls,
        ICrypto4AllNFT _crypto4AllNft
    ) {
        require(address(_accessControls) != address(0), "Crypto4AllNFTCollection: Invalid Access Controls");
        require(address(_crypto4AllNft) != address(0), "Crypto4AllNFTCollection: Invalid NFT");
        accessControls = _accessControls;
        crypto4AllNft = _crypto4AllNft;

        emit Crypto4AllNFTCollectionContractDeployed();
    }


    /**
     @notice Method for mint the NFT collection with the same metadata
     @param name Recipient of the NFT collection
     @param metadata URI for the metadata
     */
    function createCollection(
        string calldata name,
        string calldata metadata
    ) external returns (uint256) {
        require(
            accessControls.hasMinterRole(_msgSender()),
            "Crypto4AllNFTCollection.mintCollection: Sender must have the minter or contract role"
        );

        Collection storage newCollection = nftCollection[numCollection];

        newCollection.name = name; 
        newCollection.metadata = metadata; 
        newCollection.creator = msg.sender;
        newCollection.nftTokenIds = new uint256[](0);
        return numCollection++;
    }

    /**
     @notice Method for mint the NFT collection with the same metadata
     @param _collectionId Recipient of the NFT collection
     @param _tokenIds URI for the metadata
     @param _tokenPrices Garment designer address
     */
    function addNftToCollection(
        uint256 _collectionId,
        uint256[] calldata _tokenIds,
        uint256[] calldata _tokenPrices
    ) external {
        Collection storage collection = nftCollection[_collectionId];
        require(
           collection.creator == msg.sender,
            "Crypto4AllNFTCollection.addNftToCollection: Only creator can add item to the collection"
        );

        for (uint256 i = 0; i < _tokenIds.length; i ++) {
            require(crypto4AllNft.ownerOf(_tokenIds[i]) == msg.sender, "tokenId invalid");
            uint256 id = collection.nftTokenIds.length;
            collection.nftTokenIds.push(_tokenIds[i]);
            collection.indexPerTokenId[_tokenIds[i]] = id;
            collection.pricePerTokenId[_tokenIds[i]] = _tokenPrices[i];
        }

        emit AddNftToCollection(_collectionId, _tokenIds, _tokenPrices);
    }
    
    /**
     @notice Method for mint the NFT collection with the same metadata
     @param _collectionId Recipient of the NFT collection
     @param _tokenIds URI for the metadata
     */
    function removeNftFromCollection(
        uint256 _collectionId,
        uint256[] calldata _tokenIds
    ) external {
        Collection storage collection = nftCollection[_collectionId];

        for (uint256 i = 0; i < _tokenIds.length; i ++) {
            require(crypto4AllNft.ownerOf(_tokenIds[i]) == msg.sender, "tokenId invalid");
            uint256 index = collection.indexPerTokenId[_tokenIds[i]];
            collection.nftTokenIds[index] = 0;
            collection.pricePerTokenId[_tokenIds[i]] = 0;
        }

        emit RemoveNftFromCollection(_collectionId, _tokenIds);
    }

    // /**
    //  @notice Method for burn the NFT collection by given collection id
    //  @param _collectionId Id of the collection
    //  */
    // function burnCollection(uint256 _collectionId) external {
    //     Collection storage collection = nftCollection[_collectionId];

    //     for (uint i = 0; i < collection.garmentAmount; i ++) {
    //         crypto4AllNft.burn(collection.garmentTokenIds[i]);
    //     }
    //     emit BurnGarmentCollection(_collectionId);
    //     delete nftCollection[_collectionId];
    // }


    /**
     @notice Method for checking if someone owns the collection
     @param _collectionId Id of the collection
     @param _address Given address
     */
    function hasOwnedOf(uint256 _collectionId, address _address) external view returns (uint256) {
        Collection storage collection = nftCollection[_collectionId];
        uint256 _amount;
        for (uint i = 0; i < collection.nftTokenIds.length; i ++) {
            if (crypto4AllNft.ownerOf(collection.nftTokenIds[i]) == _address) {
                _amount = _amount.add(1);
            }
        }
        return _amount;
    }

    /**
     @notice Internal method for getting the NFT amount of the collection
     */

    function _balanceOfAddress(uint256 _collectionId, address _address) internal virtual view returns (uint256) {
        Collection storage collection = nftCollection[_collectionId];
        uint256 _amount;
        for (uint i = 0; i < collection.nftTokenIds.length; i ++) {
            if (crypto4AllNft.ownerOf(collection.nftTokenIds[i]) == _address) {
                _amount = _amount.add(1);
            }
        }
        return _amount;
    }
}
