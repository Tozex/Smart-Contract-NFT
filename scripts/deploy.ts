import { access } from "fs";
import { ethers, upgrades } from "hardhat";

async function main() {
  const Crypto4AllAccessControls = await ethers.getContractFactory("Crypto4AllAccessControls");
  const accessControls = await Crypto4AllAccessControls.deploy();
  await accessControls.deployed();

  // Deploy Crypto4AllNFT
  const Crypto4AllNFT = await ethers.getContractFactory("Crypto4AllNFT");
  const nft = await upgrades.deployProxy(Crypto4AllNFT, [
    accessControls.address,
    "Name",
    "Symbol",
    750
  ]);

  await nft.deployed();
  console.log('Crypto4All nft deployed to', nft.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
