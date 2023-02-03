// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol"; 
import "../AccessControl/Crypto4AllAccessControls.sol";
import "../Abstract/ERC5679.sol";


/**
 * @title Crypto4All  NFT
 * @dev Issues ERC-721 tokens 
 */
contract Crypto4AllNFT is OwnableUpgradeable, ERC5679Ext1155, ERC1155SupplyUpgradeable {
    using SafeMathUpgradeable for uint256;

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

    bool public isCollectible;

    /// @dev the percent of royalty
    uint256 public royaltyPercent;

    string public name;

    string public symbol;

    /// @dev base uri
    string private _baseURIString;

    /**
     * @notice Constructor
     */
    constructor() {
        _disableInitializers();        
        emit Crypto4AllNFTContractDeployed();
    }

    function initialize(
        Crypto4AllAccessControls _accessControls,
        string memory _name,
        string memory _symbol,
        string memory uri_,
        uint256 _royaltyPercent,
        bool _isCollectible
    ) initializer public {
        __ERC1155_init(uri_);
        __Ownable_init();

        name = _name;
        symbol = _symbol;

        accessControls = _accessControls;
        royaltyPercent = _royaltyPercent;
        _baseURIString = uri_;

        isCollectible = _isCollectible;
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, it can be overridden in child contracts.
     */
     function uri(uint256 _id) public view virtual override(ERC1155Upgradeable) returns (string memory) {
        return bytes(_baseURIString).length > 0 ? string(abi.encodePacked(_baseURIString, Strings.toString(_id))) : "";
    }

    /**
     * @notice Mint nft
     * @dev Only admin
     * @param _to The recipient of token being minted
     * @param _id The ID of the token being minted
     * @param _amount The amount of the token id being minted
     * @param _data byte data
     */
    function safeMint(
        address _to,
        uint256 _id,
        uint256 _amount,
        bytes calldata _data
    ) external override {
        require(
            accessControls.hasAdminRole(_msgSender()) || accessControls.hasMinterRole(_msgSender()),
            "Crypto4AllNFT.mint: Sender must have the admin or minter role"
        );

        require(!isCollectible || _amount + totalSupply(_id) == 1, "Max supply exceed for collectible");

        _mint(_to, _id, _amount, _data);
    }

    /**
     * @notice Batch mint nft
     * @dev Only admin
     * @param to The recipient of token being minted
     * @param ids The IDs of the token being minted
     * @param amounts The amounts of the token id being minted
     * @param data byte data
     */
    function safeMintBatch(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external override {
        require(
            accessControls.hasAdminRole(_msgSender()) || accessControls.hasMinterRole(_msgSender()),
            "Crypto4AllNFT.mint: Sender must have the admin or minter role"
        );

        for(uint256 i = 0; i < ids.length; i ++){
            require(!isCollectible || amounts[i] + totalSupply(ids[i]) == 1, "Max supply exceed for collectible");
        }
        
        _mintBatch(to, ids, amounts, data);
    }

    /**
     * @notice Burn nft
     * @dev Only approved operator or owner of nft
     * @param _from The owner of token being burned
     * @param _id The ID of the token being burned
     * @param _amount The amount of the token id being burned
     */
    function burn(
        address _from,
        uint256 _id,
        uint256 _amount,
        bytes[] calldata // _data (unused)
    ) external override {
        require(
            _from == _msgSender() || isApprovedForAll(_from, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );

        _burn(_from, _id, _amount);
    }

    /**
     * @notice Batch burn nft
     * @dev Only approved operator or owner of nft
     * @param _from The owner of token being burned
     * @param ids The IDs of the token being burned
     * @param amounts The amounts of the token id being burned
     */
    function burnBatch(
        address _from,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata // _data (unused)
    ) external override {
        require(
            _from == _msgSender() || isApprovedForAll(_from, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );

        _burnBatch(_from, ids, amounts);
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

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC5679Ext1155, ERC1155Upgradeable)
        returns (bool)
    {}
}
