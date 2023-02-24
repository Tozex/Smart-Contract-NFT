import { expect } from "chai";
import { ethers, network } from "hardhat";
import { createFixtureLoader } from "ethereum-waffle";
import { BigNumber, utils, Wallet } from "ethers";
import { deployFixture } from './utils/fixture';
import { Crypto4AllAccessControls, Crypto4AllNFT1155 } from "../typechain";


describe('Core 1155 tests for Crypto4AllNFT', function () {
    let admin: Wallet, minter: Wallet, smartContact:Wallet;
    

    let accessControls: Crypto4AllAccessControls;
    let nft1155: Crypto4AllNFT1155;
    let loadFixture: ReturnType<typeof createFixtureLoader>;

    beforeEach("Create Fixture", async function () {
        [admin, minter, smartContact] = await (ethers as any).getSigners();
        loadFixture = createFixtureLoader([
            admin
        ]);
        ({accessControls, nft1155} = await loadFixture(deployFixture));
    });
    describe('Reverts', () => {
        describe('Minting & Bunring', () => {
            it('When sender does not have a ADMIN or MINTER', async () => {
                await expect(
                    nft1155.connect(minter).safeMint(minter.address, 0, 10, "0x0000000000000000000000000000000000000000000000000000000000000000")
                ).to.revertedWith("Crypto4AllNFT.mint: Sender must have the admin or minter role");
            });

            it('When sender does not have a ADMIN or MINTER for mint many', async () => {
                await expect(
                    nft1155.connect(minter).safeMintBatch(minter.address, [1,2,3], [10,10,10], "0x0000000000000000000000000000000000000000000000000000000000000000"),
                ).to.revertedWith("Crypto4AllNFT.mint: Sender must have the admin or minter role");
            });

            it('When burner is not owner of nft', async () => {
                await nft1155.connect(admin).safeMint(admin.address, 0, 10, "0x0000000000000000000000000000000000000000000000000000000000000000");
                await expect(
                    nft1155.connect(minter).burn(minter.address, [0], [10], "0x0000000000000000000000000000000000000000000000000000000000000000"),
                ).to.revertedWith("ERC1155: burn amount exceeds balance");
            });

            it('When burner is not owner of nft on batch', async () => {
                await nft1155.connect(admin).safeMintBatch(admin.address, [0, 1, 2], [10, 10, 10], "0x0000000000000000000000000000000000000000000000000000000000000000");
                await expect(
                    nft1155.connect(minter).burnBatch(minter.address, [0, 1, 2], [10, 10, 10], ["0x0000000000000000000000000000000000000000000000000000000000000000"]),
                ).to.revertedWith("ERC1155: burn amount exceeds balance");
            });
        });
    });

    describe('Minting validation', () => {
        it('Mint Success', async () => {
            await accessControls.connect(admin).addMinterRole(minter.address);
            await nft1155.connect(minter).safeMint(minter.address, 0, 10, "0x0000000000000000000000000000000000000000000000000000000000000000");
            expect(await nft1155.balanceOf(minter.address, 0)).to.equal(10);
        });

        it('Mintmany Success', async () => {
            await accessControls.connect(admin).addMinterRole(minter.address);
            await nft1155.connect(minter).safeMintBatch(minter.address, [0, 1, 2], [10, 10, 10], "0x0000000000000000000000000000000000000000000000000000000000000000");
            expect(await nft1155.balanceOf(minter.address, 0)).to.equal(10);
            expect(await nft1155.balanceOf(minter.address, 1)).to.equal(10);
            expect(await nft1155.balanceOf(minter.address, 2)).to.equal(10);
        });
    });

    describe('Updating access controls', () => {
       it('Can update access controls as admin', async () => {
           await nft1155.connect(admin).updateAccessControls(smartContact.address);
           expect(await nft1155.accessControls()).to.equal(smartContact.address);
           expect(await nft1155.accessControls()).to.not.equal(accessControls.address);
       });

       it('Reverts when sender is not admin', async () => {
         await expect(
           nft1155.connect(minter).updateAccessControls(smartContact.address)
         ).to.revertedWith("Crypto4AllNFT.updateAccessControls: Sender must be admin");
       });
    });
})
