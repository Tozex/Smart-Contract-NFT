const NFTAuction = artifacts.require("NFTAuction");
require('dotenv').config();

module.exports = function (deployer) {
  deployer.deploy(NFTAuction, process.env.ACCESS_CONTROLS, process.env.NFT, process.env.RECIPIENT);
};
