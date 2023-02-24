import { expect } from "chai";
import { ethers, network } from "hardhat";
import { createFixtureLoader } from "ethereum-waffle";
import { BigNumber, utils, Wallet } from "ethers";
import { deployFixture } from './utils/fixture';
import { Crypto4AllAccessControls, Crypto4AllNFT } from "../typechain";


describe('Core ERC721 tests for Crypto4AllNFT', function () {
    let admin: Wallet, minter: Wallet, smartContact:Wallet;
    

    let accessControls: Crypto4AllAccessControls;
    let nft: Crypto4AllNFT;
    let loadFixture: ReturnType<typeof createFixtureLoader>;

    beforeEach("Create Fixture", async function () {
        [admin, minter, smartContact] = await (ethers as any).getSigners();
        loadFixture = createFixtureLoader([
            admin
        ]);
        ({accessControls, nft} = await loadFixture(deployFixture));
    });
    describe('Reverts', () => {
        describe('Minting & Bunring', () => {
            it('When sender does not have a ADMIN or MINTER', async () => {
                await expect(
                    nft.connect(minter).safeMint(minter.address, 0, "0x0000000000000000000000000000000000000000000000000000000000000000"),
                ).to.revertedWith("Crypto4AllNFT.mint: Sender must have the admin or minter role");
            });

            it('When sender does not have a ADMIN or MINTER for mint many', async () => {
                await expect(
                    nft.connect(minter).safeMintMany(minter.address, 100),
                ).to.revertedWith("Crypto4AllNFT.mint: Sender must have the admin or minter role");
            });

            it('When burner is not owner of nft', async () => {
                await nft.connect(admin).safeMint(admin.address, 0, "0x0000000000000000000000000000000000000000000000000000000000000000");
                await expect(
                    nft.connect(minter).burn(minter.address, 0, "0x0000000000000000000000000000000000000000000000000000000000000000"),
                ).to.revertedWith("Only nft owner can burn the nft");
            });
        });
    });

    describe('Minting validation', () => {
        it('Mint Success', async () => {
            await accessControls.connect(admin).addMinterRole(minter.address);
            await nft.connect(minter).safeMint(minter.address, 0, "0x0000000000000000000000000000000000000000000000000000000000000000");
            expect(await nft.ownerOf(0)).to.equal(minter.address);
        });

        it('Mintmany Success', async () => {
            await accessControls.connect(admin).addMinterRole(minter.address);
            await nft.connect(minter).safeMint(minter.address, 0, "0x0000000000000000000000000000000000000000000000000000000000000000"),
            await nft.connect(minter).safeMintMany(minter.address, 100),
            expect(await nft.ownerOf(2)).to.equal(minter.address);
            expect(await nft.ownerOf(10)).to.equal(minter.address);
            expect(await nft.ownerOf(20)).to.equal(minter.address);
            expect(await nft.ownerOf(99)).to.equal(minter.address);
            expect(await nft.balanceOf(minter.address)).to.equal(101);
        });
    });

    describe('Updating access controls', () => {
       it('Can update access controls as admin', async () => {
           await nft.connect(admin).updateAccessControls(smartContact.address);
           expect(await nft.accessControls()).to.equal(smartContact.address);
           expect(await nft.accessControls()).to.not.equal(accessControls.address);
       });

       it('Reverts when sender is not admin', async () => {
         await expect(
           nft.connect(minter).updateAccessControls(smartContact.address)
         ).to.revertedWith("Crypto4AllNFT.updateAccessControls: Sender must be admin");
       });
    });
})
