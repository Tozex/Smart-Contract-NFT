import { expect, util } from "chai";
import { ethers, network } from "hardhat";
import { createFixtureLoader } from "ethereum-waffle";
import { BigNumber, utils, Wallet, ContractTransaction } from "ethers";
import { deployFixture } from './utils/fixture';
import { Crypto4AllAccessControls, Crypto4AllNFT, NFTAuctionMock } from "../typechain";

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
    let admin: Wallet, minter: Wallet, smartContact:Wallet, other1: Wallet, other2: Wallet,
     platformFeeAddress: Wallet, owner: Wallet, bidder: Wallet, bidder2: Wallet;
    

    let accessControls: Crypto4AllAccessControls;
    let nft: Crypto4AllNFT;
    let nftAuction: NFTAuctionMock;
    let loadFixture: ReturnType<typeof createFixtureLoader>;

    before("Create Fixture", async function () {
        [admin, minter, smartContact, other1, other2, platformFeeAddress, owner, bidder, bidder2] = await (ethers as any).getSigners();
        loadFixture = createFixtureLoader([
            admin
        ]);
        ({accessControls, nft, nftAuction} = await loadFixture(deployFixture));
    });


    describe('Admin functions', () => {
        before(async () => {
            await accessControls.connect(admin).addMinterRole(minter.address);
            await nft.connect(minter).safeMintMany(minter.address, 100),
            await nft.connect(minter).approve(nftAuction.address, 1);
            await nftAuction.connect(admin).setNowOverride('2');
            await nftAuction.connect(minter).createAuction(
                1,
                '1',
                '0',
                '10',
            );
            await nftAuction.connect(bidder).placeBid(1, {value: utils.parseEther('0.2')});
        });

        describe('updateMinBidIncrement()', () => {
            it('fails when not admin', async () => {
                await expect(
                    nftAuction.connect(bidder).updateMinBidIncrement('1')
                ).to.revertedWith('NFTAuction.updateMinBidIncrement: Sender must be admin');
            });

            it('successfully updates min bid', async () => {
                const original = await nftAuction.connect(admin).minBidIncrement();
                expect(original).to.equal(utils.parseEther('0.1'));

                await nftAuction.connect(admin).updateMinBidIncrement(utils.parseEther('0.2'));

                const updated = await nftAuction.minBidIncrement();
                expect(updated).to.equal(utils.parseEther('0.2'));
            });
        });

        describe('updateAuctionReservePrice()', () => {
            it('fails when not admin', async () => {
                await expect(
                    nftAuction.connect(bidder).updateAuctionReservePrice(1, '1')                    
                ).to.revertedWith('NFTAuction.updateAuctionReservePrice: Sender must be admin');
            });

            it('fails when auction doesnt exist', async () => {
                await expect(
                    nftAuction.connect(admin).updateAuctionReservePrice(2, '1')
                ).to.revertedWith("NFTAuction.updateAuctionReservePrice: No Auction exists");
            });

            it('successfully updates auction reserve', async () => {
                let {_reservePrice} = await nftAuction.getAuction(1);
                expect(_reservePrice).to.equal(1);

                await nftAuction.connect(admin).updateAuctionReservePrice(1, 2);

                let {_reservePrice: updateReservePrice} = await nftAuction.getAuction(1);
                expect(updateReservePrice).to.equal('2');
            });
        });

        describe('updateAuctionStartTime()', () => {
            it('fails when not admin', async () => {
                await expect(
                    nftAuction.connect(bidder).updateAuctionStartTime('1', '1')
                ).to.revertedWith('NFTAuction.updateAuctionStartTime: Sender must be admin');
            });

            it('fails when auction does not exist', async () => {
                await expect(
                    nftAuction.connect(admin).updateAuctionStartTime('2', '1')                   
                ).to.revertedWith("NFTAuction.updateAuctionStartTime: No Auction exists");
            });

            it('successfully updates auction start time', async () => {
                let {_startTime} = await nftAuction.getAuction('1');
                expect(_startTime).to.equal('0');

                await nftAuction.connect(admin).updateAuctionStartTime('1', '2');

                let {_startTime: updated} = await nftAuction.getAuction('1');
                expect(updated).to.equal('2');
            });
        });

        describe('updateAuctionEndTime()', () => {
            it('fails when not admin', async () => {
                await expect(
                    nftAuction.connect(bidder).updateAuctionEndTime('1', '1')                
                ).to.revertedWith('NFTAuction.updateAuctionEndTime: Sender must be admin');
            });

            it('fails when no auction exists', async () => {
                await expect(
                    nftAuction.connect(admin).updateAuctionEndTime('2', '1')                
                ).to.revertedWith("NFTAuction.updateAuctionEndTime: No Auction exists");
            });

            it('fails when wnd time must be greater than start', async () => {
                nftAuction.connect(admin).updateAuctionStartTime('1', '10');
                await expect(
                    nftAuction.connect(admin).updateAuctionEndTime('1', '9')                
                ).to.revertedWith('NFTAuction.updateAuctionEndTime: End time must be greater than start');
            });

            it('fails when end time has passed', async () => {
                await nftAuction.setNowOverride('12');
                await expect(
                    nftAuction.connect(admin).updateAuctionEndTime('1', '11')               
                ).to.revertedWith('NFTAuction.updateAuctionEndTime: End time passed. Nobody can bid');
            });

            it('successfully updates auction end time', async () => {
                let {_endTime} = await nftAuction.getAuction('1');
                expect(_endTime).to.equal('10');

                await nftAuction.connect(admin).updateAuctionEndTime('1', '20');

                let {_endTime: updated} = await nftAuction.getAuction('1');
                expect(updated).to.equal('20');
            });
        });

        describe('updateAccessControls()', () => {
            it('fails when not admin', async () => {
                await expect(
                    nftAuction.connect(bidder).updateAccessControls(accessControls.address)
                ).to.revertedWith('NFTAuction.updateAccessControls: Sender must be admin');
            });

            it('reverts when trying to set recipient as ZERO address', async () => {
                await expect(
                    nftAuction.connect(admin).updateAccessControls(ethers.constants.AddressZero)
                ).to.revertedWith('NFTAuction.updateAccessControls: Zero Address');
            });
        });

        describe('updatePlatformFee()', () => {
            it('fails when not admin', async () => {
                await expect(
                    nftAuction.connect(bidder).updatePlatformFee('123')
                ).to.revertedWith('NFTAuction.updatePlatformFee: Sender must be admin');
            });
            it('successfully updates access controls', async () => {
                const original = await nftAuction.platformFee();
                expect(original).to.equal('20');

                await nftAuction.connect(admin).updatePlatformFee('999');

                const updated = await nftAuction.platformFee();
                expect(updated).to.equal('999');

                await nftAuction.connect(admin).updatePlatformFee('20');
            });
        });

        describe('updatePlatformFeeRecipient()', () => {
            it('reverts when not admin', async () => {
                await expect(
                    nftAuction.connect(bidder).updatePlatformFeeRecipient(owner.address)
                ).to.revertedWith('NFTAuction.updatePlatformFeeRecipient: Sender must be admin');
            });

            it('reverts when trying to set recipient as ZERO address', async () => {
                await expect(
                    nftAuction.updatePlatformFeeRecipient(ethers.constants.AddressZero)
                ).to.revertedWith('NFTAuction.updatePlatformFeeRecipient: Zero address');
            });

            it('successfully updates platform fee recipient', async () => {
                const original = await nftAuction.platformFeeRecipient();
                expect(original).to.equal(admin.address);

                await nftAuction.connect(admin).updatePlatformFeeRecipient(bidder2.address);

                const updated = await nftAuction.platformFeeRecipient();
                expect(updated).to.equal(bidder2.address);
            });
        });

        describe('Auction resulting', () => {
            it('Successfully results the auction', async () => {
                await await nftAuction.connect(admin).setNowOverride('22');

                expect(await nftAuction.connect(admin).resultAuction(1))
                .be.emit(nftAuction, "AuctionResulted")
                .withArgs(1, bidder.address, utils.parseEther('0.2'));

                const {_bidder, _bid} = await nftAuction.getHighestBidder(1);
                expect(_bid).to.equal('0');
                expect(_bidder).to.equal(ethers.constants.AddressZero);

                const {_reservePrice, _startTime, _endTime, _resulted} = await nftAuction.getAuction(1);
                expect(_reservePrice).to.equal('2');
                expect(_startTime).to.equal('10');
                expect(_endTime).to.equal('20');
                expect(_resulted).to.equal(true);
            });
        });
    });

    describe('createAuction()', async () => {
        before(async () => {
            await nft.connect(minter).approve(nftAuction.address, '2');
        });

        describe('validation', async () => {

            it('fails if does not have minter role', async () => {
                await expect(
                    nftAuction.connect(bidder).createAuction('2', '1', '0', '10')
                ).to.revertedWith('NFTAuction.createAuction: Sender must have the minter role');
            });

            it('fails if endTime is in the past', async () => {
                await nftAuction.setNowOverride('12');
                await expect(
                    nftAuction.connect(minter).createAuction('2', '1', '0', '10')
                ).to.revertedWith("NFTAuction.createAuction: End time passed. Nobody can bid.");
            });

            it('fails if endTime greater than startTime', async () => {
                await nftAuction.setNowOverride('2');
                await expect(
                    nftAuction.connect(minter).createAuction('2', '1', '1', '0')
                ).to.revertedWith('NFTAuction.createAuction: End time must be greater than start');
            });

            it('fails if token already has auction in play', async () => {
                await nftAuction.setNowOverride('2');
                await nftAuction.connect(minter).createAuction('2', '1', '0', '10');

                await expect(
                    nftAuction.connect(minter).createAuction('2', '1', '1', '3')
                ).to.revertedWith('NFTAuction.createAuction: Cannot relist');
            });

            it('fails if you dont own the token', async () => {
                await nftAuction.setNowOverride('2');

                // await nftAuction.connect(minter).createAuction('2', '1', '0', '10');

                await expect(
                    nftAuction.connect(minter).createAuction('3', '1', '1', '3')
                ).to.revertedWith('NFTAuction.createAuction: Not owner and or contract not approved');
            });

            it('fails if token does not exist', async () => {
                await nftAuction.setNowOverride('10');

                await expect(
                    nftAuction.connect(minter).createAuction('199', '1', '1', '11')
                ).to.reverted;
            });
        });

        describe('successful creation', async () => {
            it('Token retains in the ownership of the auction creator', async () => {
                await nftAuction.setNowOverride('2');
                await nft.connect(minter).approve(nftAuction.address, '3');
                await nftAuction.connect(minter).createAuction('3', '1', '0', '10');

                const owner = await nft.ownerOf('3');
                expect(owner).to.be.equal(minter.address);
            });
        });

    });

    describe('placeBid()', async () => {

        describe('validation', () => {

            it('will fail with 721 token not on auction', async () => {
                await expect(
                    nftAuction.connect(bidder).placeBid(999, {value: 1})
                ).to.revertedWith('NFTAuction.placeBid: Bidding outside of the auction window');
            });

            it('will fail with valid token but no auction', async () => {
                await expect(
                    nftAuction.connect(bidder).placeBid('4', {value: 1})
                ).to.revertedWith('NFTAuction.placeBid: Bidding outside of the auction window');
            });

            it('will fail when auction finished', async () => {
                await nftAuction.setNowOverride('11');
                await expect(
                    nftAuction.connect(bidder).placeBid('2', {value: 1})
                ).to.revertedWith('NFTAuction.placeBid: Bidding outside of the auction window');
            });

            it('will fail when outbidding someone by less than the increment', async () => {
                await nftAuction.setNowOverride('2');
                await nftAuction.connect(bidder2).placeBid(2, {value: utils.parseEther('0.2')});

                await expect(
                    nftAuction.connect(bidder2).placeBid('2', {value: utils.parseEther('0.2')})
                ).to.revertedWith('NFTAuction.placeBid: Failed to outbid highest bidder');
            });
        });

        describe('successfully places bid', () => {

            it('places bid and you are the top owner', async () => {
                await nftAuction.setNowOverride('2');
                await nftAuction.connect(bidder).placeBid('2', {value: utils.parseEther('0.4')});

                const {_bidder, _bid} = await nftAuction.getHighestBidder('2');
                expect(_bid).to.equal(utils.parseEther('0.4'));
                expect(_bidder).to.equal(bidder.address);

                const {_reservePrice, _startTime, _endTime, _resulted} = await nftAuction.getAuction('2');
                expect(_reservePrice).to.equal('1');
                expect(_startTime).to.equal('0');
                expect(_endTime).to.equal('10');
                expect(_resulted).to.be.equal(false);
            });

            it('will refund the top bidder if found', async () => {
                await nftAuction.setNowOverride('2');


                // make a new bid, out bidding the previous bidder
                await expect(() =>
                    nftAuction.connect(bidder2).placeBid('2', {value: utils.parseEther('0.6')})
                ).to.changeEtherBalance(bidder, utils.parseEther('0.4'));

                // Funds sent back to original bidder

                const {_bidder, _bid} = await nftAuction.getHighestBidder('2');
                expect(_bid).to.equal(utils.parseEther('0.6'));
                expect(_bidder).to.equal(bidder2.address);
            });

            it('successfully increases bid', async () => {
                await nftAuction.setNowOverride('2');

                await nftAuction.connect(bidder).placeBid('2', {value: utils.parseEther('0.8')});

                const {_bidder, _bid} = await nftAuction.getHighestBidder('2');
                expect(_bid).to.equal(utils.parseEther('0.8'));
                expect(_bidder).to.equal(bidder.address);

                await nftAuction.connect(bidder).placeBid('2', {value: utils.parseEther('1')});

                // check that the bidder has only really spent 0.8 ETH plus gas due to 0.2 ETH refund

                const {_bidder: newBidder, _bid: newBid} = await nftAuction.getHighestBidder('2');
                expect(newBid).to.equal(utils.parseEther('1'));
                expect(newBidder).to.equal(bidder.address);
            })

            it('successfully outbid bidder', async () => {
                await nftAuction.setNowOverride('2');

                // Bidder 2 outbids bidder 1
                await nftAuction.connect(bidder2).placeBid('2', {value: utils.parseEther('1.2')});

                // check that the bidder has only really spent 0.8 ETH plus gas due to 0.2 ETH refund

                const {_bidder: newBidder, _bid: newBid} = await nftAuction.getHighestBidder('2');
                expect(newBid).to.equal(utils.parseEther('1.2'));
                expect(newBidder).to.equal(bidder2.address);

                await nftAuction.connect(bidder).placeBid('2', {value: utils.parseEther('1.4')});
            })
        });
    });

    describe('withdrawBid()', async () => {

        it('fails with withdrawing a bid which does not exist', async () => {
            await expect(
                nftAuction.connect(bidder2).withdrawBid(999)
            ).to.revertedWith('NFTAuction.withdrawBid: You are not the highest bidder');
        });

        it('fails with withdrawing a bid which you did not make', async () => {
            await expect(
                nftAuction.connect(bidder2).withdrawBid('2')
            ).to.revertedWith('NFTAuction.withdrawBid: You are not the highest bidder');
        });

        it('fails when withdrawing after auction end', async () => {
            await nftAuction.setNowOverride('12');
            await expect(
                nftAuction.connect(bidder).withdrawBid('2')
            ).to.revertedWith("NFTAuction.withdrawBid: Past auction end");
        });

        it('fails when the contract is paused', async () => {
            const {_bidder: originalBidder, _bid: originalBid} = await nftAuction.getHighestBidder('2');
            expect(originalBid).to.equal(utils.parseEther('1.4'));
            expect(originalBidder).to.equal(bidder.address);


            await nftAuction.connect(admin).toggleIsPaused();
            await expect(
                nftAuction.connect(bidder).withdrawBid('2')
            ).to.revertedWith("Function is currently paused");
            await nftAuction.connect(admin).toggleIsPaused();
        });

        it('successfully withdraw the bid', async () => {
            await nftAuction.setNowOverride('2');

            const {_bidder: originalBidder, _bid: originalBid} = await nftAuction.getHighestBidder('2');
            expect(originalBid).to.equal(utils.parseEther('1.4'));
            expect(originalBidder).to.equal(bidder.address);

            await nftAuction.connect(bidder).withdrawBid('2');


            const {_bidder, _bid} = await nftAuction.getHighestBidder('2');
            expect(_bid).to.equal('0');
            expect(_bidder).to.equal(ethers.constants.AddressZero);
        });
    });

    describe('resultAuction()', async () => {

        describe('validation', () => {

            it('cannot result if not an admin', async () => {
                await expect(
                    nftAuction.connect(bidder).resultAuction('2')
                ).to.revertedWith('NFTAuction.resultAuction: Sender must be admin or smart contract');
            });

            it('cannot result if auction has not ended', async () => {
                await expect(
                    nftAuction.connect(admin).resultAuction('2')
                ).to.revertedWith('NFTAuction.resultAuction: The auction has not ended');
            });

            it('cannot result if auction does not exist', async () => {
                await expect(
                    nftAuction.connect(admin).resultAuction(9999)
                ).to.revertedWith('NFTAuction.resultAuction: Auction does not exist');
            });


            it('cannot result if the auction has no winner', async () => {
                // Lower reserve to zero
                await nftAuction.connect(admin).updateAuctionReservePrice('2', '0');
                await nftAuction.setNowOverride('12');
                await expect(
                    nftAuction.connect(admin).resultAuction('2')
                ).to.revertedWith('NFTAuction.resultAuction: no open bids');
                await nftAuction.connect(admin).updateAuctionReservePrice('2', '1');
            });

            it('cannot result if there is no approval', async () => {
                await nftAuction.setNowOverride('12');

                await nft.connect(minter).approve(ethers.constants.AddressZero, '2');

                await expect(
                    nftAuction.connect(admin).resultAuction('2')
                ).to.revertedWith("NFTAuction.resultAuction: auction not approved");
            });
        });

        describe('successfully resulting an auction', async () => {

            it('transfer token to the winner', async () => {
                await nftAuction.setNowOverride('2');

                await nftAuction.connect(bidder).placeBid('2', {value: utils.parseEther('1.4')});

                await nftAuction.setNowOverride('12');

                await nft.connect(minter).approve(nftAuction.address, '2');

                expect(await nft.ownerOf('2')).to.be.equal(minter.address);

                await nftAuction.connect(admin).resultAuction('2');

                expect(await nft.ownerOf('2')).to.be.equal(bidder.address);
            });
        });

    });
})
