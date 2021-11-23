const Crypto4AllNFT = artifacts.require("Crypto4AllNFT");
require('dotenv').config();

module.exports = function (deployer) {
  deployer.deploy(Crypto4AllNFT, process.env.ACCESS_CONTROLS);
};
