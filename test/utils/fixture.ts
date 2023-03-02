import { ethers, upgrades } from "hardhat";
import { Wallet, utils } from "ethers";

import { 
    Crypto4AllAccessControls, 
    Crypto4AllNFT, 
    Crypto4AllNFT1155, 
    NFTAuctionMock, 
    NFTMarketplace, 
    NFTMarketplace1155,
    NFTSale,
    NFTSale1155
} from "../../typechain";

interface Crypto4AllFixture {
    accessControls: Crypto4AllAccessControls;
    nft: Crypto4AllNFT;
    nft1155: Crypto4AllNFT1155;
    nftAuction: NFTAuctionMock;
    nftMarketplace: NFTMarketplaceMock;
    nftMarketplace1155: NFTMarketplace1155;
    nftSale: NFTSale;
    nftSale1155: NFTSale1155;
}

export async function deployFixture(
    [admin]: Wallet[]
): Promise<Crypto4AllFixture> {

    const accessControlsFactory = await ethers.getContractFactory("Crypto4AllAccessControls");
    const accessControlsInstance = await accessControlsFactory.connect(admin).deploy();
    await accessControlsInstance.deployed();

    const nftFactory = await ethers.getContractFactory("Crypto4AllNFT");
    const nftInstance = await upgrades.deployProxy(nftFactory, [
        accessControlsInstance.address,
        "Crypto4All NFT",
        "CNFT",
        "uri",
        5
    ]);
    await nftInstance.deployed();

    const nft1155Factory = await ethers.getContractFactory("Crypto4AllNFT1155");
    const nft1155Instance = await upgrades.deployProxy(nft1155Factory, [
        accessControlsInstance.address,
        "Crypto4All NFT1155",
        "CNFT1155",
        "uri",
        5,
        false
    ]);
    await nft1155Instance.deployed();

    const nftAuctionFactory = await ethers.getContractFactory("NFTAuctionMock");
    const nftAuctionInstance = await nftAuctionFactory.connect(admin).deploy(
        accessControlsInstance.address,
        nftInstance.address,
        admin.address,
    );
    await nftAuctionInstance.deployed();
    
    const nftMarketplaceFactory = await ethers.getContractFactory("NFTMarketplaceMock");
    const nftMarketplaceInstance = await nftMarketplaceFactory.connect(admin).deploy(
        accessControlsInstance.address,
        nftInstance.address,
        admin.address,
    );
    await nftMarketplaceInstance.deployed();

    const nftMarketplace1155Factory = await ethers.getContractFactory("NFTMarketplace1155");
    const nftMarketplace1155Instance = await nftMarketplace1155Factory.connect(admin).deploy(
        accessControlsInstance.address,
        nftInstance.address,
        admin.address,
    );
    await nftMarketplace1155Instance.deployed();

    const nftSaleFactory = await ethers.getContractFactory("NFTSale");
    const nftSaleInstance = await nftSaleFactory.connect(admin).deploy(
        nftInstance.address,
        admin.address,
        "0x0000000000000000000000000000000000000000000000000000000000000000"
    );
    await nftSaleInstance.deployed();
    
    const nftSale1155Factory = await ethers.getContractFactory("NFTSale1155");
    const nftSale1155Instance = await nftSale1155Factory.connect(admin).deploy(
        nft1155Instance.address,
        admin.address,
        "0x0000000000000000000000000000000000000000000000000000000000000000"
    );
    await nftSale1155Instance.deployed();

    // Fixtures can return anything you consider useful for your tests
    return { 
        accessControls: accessControlsInstance as Crypto4AllAccessControls,
        nft: nftInstance as Crypto4AllNFT,
        nft1155: nft1155Instance as Crypto4AllNFT1155,
        nftAuction: nftAuctionInstance as NFTAuctionMock,
        nftMarketplace: nftMarketplaceInstance as NFTMarketplaceMock,
        nftMarketplace1155: nftMarketplace1155Instance as NFTMarketplace1155,
        nftSale: nftSaleInstance as NFTSale,
        nftSale1155: nftSale1155Instance as NFTSale1155
    };
}