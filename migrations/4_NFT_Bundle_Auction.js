const NFTBundleAuction = artifacts.require("NFTBundleAuction");
require('dotenv').config();

module.exports = function (deployer) {
  deployer.deploy(NFTBundleAuction, process.env.ACCESS_CONTROLS, process.env.NFT, process.env.RECIPIENT);
};
