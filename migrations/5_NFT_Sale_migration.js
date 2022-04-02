const NFTSale = artifacts.require("NFTSale");
require('dotenv').config();

module.exports = function (deployer) {
  deployer.deploy(NFTSale, process.env.NFT, "0x3D0b45BCEd34dE6402cE7b9e7e37bDd0Be9424F3");
};
