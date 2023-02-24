import { expect } from "chai";
import { ethers, network } from "hardhat";
import { createFixtureLoader } from "ethereum-waffle";
import { BigNumber, utils, Wallet, ContractTransaction } from "ethers";
import { keccak256 } from "ethers/lib/utils";
import { MerkleTree } from "merkletreejs";
import { deployFixture } from './utils/fixture';
import { Crypto4AllAccessControls, Crypto4AllNFT, NFTSale } from "../typechain";

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
    let admin: Wallet, minter: Wallet, smartContact:Wallet, other1: Wallet, other2: Wallet;
    

    let accessControls: Crypto4AllAccessControls;
    let nft: Crypto4AllNFT;
    let nftSale: NFTSale;
    let loadFixture: ReturnType<typeof createFixtureLoader>;

    before("Create Fixture", async function () {
        [admin, minter, smartContact, other1, other2] = await (ethers as any).getSigners();
        loadFixture = createFixtureLoader([
            admin
        ]);
        ({accessControls, nft, nftSale} = await loadFixture(deployFixture));
    });

    describe("#updateIsSale", async function () {
        it("Should throw out other users attempting to set sale status", async function () {
            await expect(
                nftSale.connect(other1).updateIsSale(SalesStatus.Allowlist)
            ).be.reverted;
        });

        it("Admin should be able to update the sale status", async function () {
            await nftSale.connect(admin).updateIsSale(SalesStatus.Allowlist);

            expect(await nftSale.salesStatus()).to.equal(SalesStatus.Allowlist);
        });
    });

    describe("#updateTokenPrice", async function () {
        it("Should throw out other users attempting to update token price", async function () {
            await expect(
                nftSale.connect(other1).updateNftPrice(utils.parseEther("1.2"))
            ).be.reverted;
        });

        it("Admin should be able to update the token price", async function () {
            await nftSale.connect(admin).updateNftPrice(utils.parseEther("0.5"));

            expect(await nftSale.nftPrice()).to.equal(utils.parseEther("0.5"));
        });
    });
    
    describe("#updateMerkleRoot", async function () {
        it("Should throw out other users attempting to update merkle root", async function () {
            await expect(
                nftSale.connect(other1).updateMerkleRoot("0x000000000000000000000000000000000000000000000000000000000000000a")
            ).be.reverted;
        });

        it("Admin should be able to update the merkle root", async function () {
            expect(await nftSale.connect(admin).updateMerkleRoot("0x000000000000000000000000000000000000000000000000000000000000000a"))
            .be.emit(nftSale, "UpdateMerkleRoot")
            .withArgs("0x000000000000000000000000000000000000000000000000000000000000000a");
        });
    });

    describe("#Buy NFT", async function () {
        it("Should throw out error when sale status is pause", async function () {
            await nftSale.connect(admin).updateIsSale(SalesStatus.Pause);
            await expect(
                nftSale.connect(other1).buyNft([])
            ).be.revertedWith("NFTSale.buyNft: sale not enabled");
        });

        it("Should throw out error when price is not enough", async function () {
            await nftSale.connect(admin).updateIsSale(SalesStatus.Public);
            await expect(
                nftSale.connect(other1).buyNft([], { value: utils.parseEther("0.1") })
            ).be.revertedWith("NFTSale.buyNft: amount not same");
        });

        it("Should throw out error when there is no nft in sale contract", async function () {
            await expect(
                nftSale.connect(other1).buyNft([], { value: utils.parseEther("0.5") })
            ).be.revertedWith("nothing left");
        });

        it("Should mint tokens on whitelist sale, and only once", async function () {
            await nftSale.connect(admin).updateIsSale(SalesStatus.Allowlist);
            await nft.connect(admin).safeMintMany(nftSale.address, 100);
            
            const tokenPrice = await nftSale.nftPrice();
            const whitelistData = [
                [other1.address],
                [other2.address],
            ];
            const leaves = whitelistData.map((item) =>
                utils.solidityKeccak256(["address"], item)
            );
            const tree = new MerkleTree(leaves, keccak256, {
                sortPairs: true,
                sortLeaves: true,
            });
            const root = tree.getHexRoot();
            const hexProof = tree.getHexProof(
                utils.solidityKeccak256(["address"], whitelistData[0])
            );
            // Set Merkle Tree Root
            await nftSale.connect(admin).updateMerkleRoot(root);
            
            await nftSale.connect(other1).buyNft(hexProof, {
                value: tokenPrice.mul(1),
            });

            expect(await nft.balanceOf(other1.address)).to.eq(
                1
            );
            // Try to mint again, should fail
            await expect(
                nftSale.connect(other1).buyNft(hexProof, {
                    value: tokenPrice.mul(1),
                })
            ).be.reverted;
        });

        it("Should mint tokens as many as you can on public sale", async function () {
            await nftSale.connect(admin).updateIsSale(SalesStatus.Public);
            
            const tokenPrice = await nftSale.nftPrice();
            
            await nftSale.connect(other2).buyNft([], {
                value: tokenPrice.mul(1),
            });

            expect(await nft.balanceOf(other2.address)).to.eq(
                1
            );
            await nftSale.connect(other2).buyNft([], {
                value: tokenPrice.mul(1),
            });

            expect(await nft.balanceOf(other2.address)).to.eq(
                2
            );
        });
    });

    describe("#withdraw", function () {
        it("Should throw out non-owner attempting to withdraw", async function () {
        await expect(nftSale.connect(other1).withdrawEth()).be.reverted;
        });

        it("Owner should be able to withdraw funds", async function () {
        const contractEthBalance = await ethers.provider.getBalance(
            nftSale.address
        );

        const originalBalance = await ethers.provider.getBalance(admin.address);
        const transactionFee = await calcTransactionFee(nftSale.connect(admin).withdrawEth());

        const newBalance = await ethers.provider.getBalance(admin.address);

        expect(newBalance).to.eq(
            originalBalance.add(contractEthBalance).sub(transactionFee)
        );
        });
    });

})
