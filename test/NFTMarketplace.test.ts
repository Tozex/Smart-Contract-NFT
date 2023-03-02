import { expect, util } from "chai";
import { ethers, network } from "hardhat";
import { createFixtureLoader } from "ethereum-waffle";
import { BigNumber, utils, Wallet, ContractTransaction } from "ethers";
import { deployFixture } from './utils/fixture';
import { Crypto4AllAccessControls, Crypto4AllNFT, NFTMarketplaceMock } from "../typechain";

enum SalesStatus {
    Pause = 0,
    Allowlist = 1,
    Public = 2
}

async function calcTransactionFee(
    transactionPromise: Promise<ContractTransaction>
): Promise<BigNumber> {
    const transaction = await transactionPromise;
    const receipt = await transaction.wait();

    return receipt.gasUsed.mul(transaction.gasPrice!);
}
  
describe('Sale tests for Crypto4AllNFT', function () {
    let admin: Wallet, minter: Wallet, smartContract:Wallet, tokenBuyer: Wallet, newRecipient: Wallet,
     platformFeeAddress: Wallet, owner: Wallet;
    

    let accessControls: Crypto4AllAccessControls;
    let nft: Crypto4AllNFT;
    let nftMarketplace: NFTMarketplaceMock;
    let loadFixture: ReturnType<typeof createFixtureLoader>;

    before("Create Fixture", async function () {
        [admin, smartContract, platformFeeAddress, minter, owner, tokenBuyer, newRecipient] = await (ethers as any).getSigners();
        loadFixture = createFixtureLoader([
            admin
        ]);
        ({accessControls, nft, nftMarketplace} = await loadFixture(deployFixture));
    });


    describe('Admin functions', () => {
      before(async () => {
        await accessControls.connect(admin).addMinterRole(minter.address);
        await nft.connect(minter).safeMintMany(minter.address, 100),
        await nft.connect(minter).approve(nftMarketplace.address, '0');
        await nftMarketplace.connect(admin).setNowOverride('2');
        await nftMarketplace.connect(minter).createOffer(
          '0',
          utils.parseEther('0.1'),  // Price of 0.1 eth
          '1',
          '10'
        );
      });
  
      describe('updateMarketplacePlatformFee()', () => {
        it('fails when not admin', async () => {
          await expect(
            nftMarketplace.connect(tokenBuyer).updateMarketplacePlatformFee(200)
          ).to.revertedWith('NFTMarketplace.updateMarketplacePlatformFee: Sender must be admin');
        });
        it('successfully updates platform fee', async () => {
          const original = await nftMarketplace.platformFee();
          expect(original).to.equal('20');
  
          await nftMarketplace.connect(admin).updateMarketplacePlatformFee('200');
  
          const updated = await nftMarketplace.platformFee();
          expect(updated).to.equal('200');
        });
      });
    
      describe('updateAccessControls()', () => {
        it('fails when not admin', async () => {
          await expect(
            nftMarketplace.connect(tokenBuyer).updateAccessControls(accessControls.address)
          ).to.revertedWith('NFTMarketplace.updateAccessControls: Sender must be admin');
        });
  
        it('reverts when trying to set recipient as ZERO address', async () => {
          await expect(
            nftMarketplace.connect(admin).updateAccessControls(ethers.constants.AddressZero)
          ).to.revertedWith('NFTMarketplace.updateAccessControls: Zero Address');
        });
      });
  
      describe('updatePlatformFeeRecipient()', () => {
        it('reverts when not admin', async () => {
          await expect(
            nftMarketplace.connect(tokenBuyer).updatePlatformFeeRecipient(owner.address)
          ).to.revertedWith('NFTMarketplace.updatePlatformFeeRecipient: Sender must be admin');
        });
  
        it('reverts when trying to set recipient as ZERO address', async () => {
          await expect(
            nftMarketplace.connect(admin).updatePlatformFeeRecipient(ethers.constants.AddressZero)
          ).to.revertedWith('NFTMarketplace.updatePlatformFeeRecipient: Zero address');
        });
  
        it('successfully updates platform fee recipient', async () => {
          const original = await nftMarketplace.platformFeeRecipient();
          expect(original).to.be.equal(admin.address);
  
          await nftMarketplace.connect(admin).updatePlatformFeeRecipient(newRecipient.address);
  
          const updated = await nftMarketplace.platformFeeRecipient();
          expect(updated).to.be.equal(newRecipient.address);
        });
      });
  
    });
  
    describe('createOffer()', async () => {
      before(async () => {
        await accessControls.connect(admin).addMinterRole(minter.address);
        await nft.connect(minter).safeMintMany(minter.address, 100);
      });

      describe('validation', async () => {
  
        it('fails if token already has marketplace in play', async () => {
          await nftMarketplace.setNowOverride('2');
          await nft.connect(minter).approve(nftMarketplace.address, '1');
          await nftMarketplace.connect(minter).createOffer('1',  utils.parseEther('0.1'), '1', '10');
  
          await expect(
            nftMarketplace.connect(minter).createOffer('1',  utils.parseEther('0.1'), '1', '10')
          ).to.revertedWith('NFTMarketplace.createOffer: Cannot duplicate current offer');
        });
  
        it('fails if contract is paused', async () => {
          await nftMarketplace.setNowOverride('2');
          await nftMarketplace.connect(admin).toggleIsPaused();
          await expect(
              nftMarketplace.createOffer('99', utils.parseEther('0.1'), '1', '10')
          ).to.revertedWith("Function is currently paused");
          await nftMarketplace.connect(admin).toggleIsPaused();
        });
  
        it('fails if you try to create an offer with a non minter address', async () => {
          await nftMarketplace.setNowOverride('2');
          await expect(
              nftMarketplace.connect(tokenBuyer).createOffer('98', utils.parseEther('0.05'), '1', '10')
          ).to.revertedWith("NFTMarketplace.createOffer: Sender must have the minter or admin role");
        });
      });
    });
  
    describe('confirmOffer()', async () => {

      describe('try to buy offer', () => {
   
        it('will fail if we have not reached start time', async () => {
          await nftMarketplace.setNowOverride('0');
          await expect(
              nftMarketplace.connect(tokenBuyer).confirmOffer(0, {value: utils.parseEther('0.1')}),
          ).to.revertedWith("NFTMarketplace.confirmOffer: Purchase outside of the offer window");
        });
        
        it('will fail if we have not reached end time', async () => {
          await nftMarketplace.setNowOverride('12');
          await expect(
              nftMarketplace.connect(tokenBuyer).confirmOffer(0, {value: utils.parseEther('0.1')}),
          ).to.revertedWith("NFTMarketplace.confirmOffer: Purchase outside of the offer window");
        });

        it('will fail if bid value is not enough', async () => {
          await nftMarketplace.setNowOverride('2');
          await expect(
              nftMarketplace.connect(tokenBuyer).confirmOffer(0, {value: utils.parseEther('0.001')}),
          ).to.revertedWith("NFTMarketplace.confirmOffer: Failed to supply funds");
        });

        it('buys the offer', async () => {
          await nftMarketplace.setNowOverride('2');
  
          const {_primarySalePrice, _startTime, _endTime} = await nftMarketplace.getOffer('1');
          expect(_primarySalePrice).to.equal(utils.parseEther('0.1'));
          expect(_startTime).to.equal('1');
          expect(_endTime).to.equal('10');

          await nftMarketplace.connect(tokenBuyer).confirmOffer('0', {value: utils.parseEther('0.1')});
          expect(await nft.ownerOf(0)).to.equal(tokenBuyer.address);
        });
      });
    });
  
    describe('cancelOffer()', async () => {
  
      describe('validation', async () => {
  
        it('cannot cancel if not an admin', async () => {
          await expect(
            nftMarketplace.connect(tokenBuyer).cancelOffer(0),
          ).to.revertedWith('NFTMarketplace.cancelOffer: Sender must be admin or minter contract');
        });
  
        it('cannot cancel if marketplace does not exist', async () => {
          await expect(
            nftMarketplace.connect(admin).cancelOffer(9999),
          ).to.revertedWith('NFTMarketplace.cancelOffer: Offer does not exist');
        });
  
        it('can cancel an offer', async () => {
          expect(await nftMarketplace.connect(admin).cancelOffer(1))
            .be.emit(nftMarketplace, "OfferCancelled")
            .withArgs(1);
        });
      });
    });
  
})
