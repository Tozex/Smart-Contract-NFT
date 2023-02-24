import { expect } from "chai";
import { ethers, network } from "hardhat";
import { createFixtureLoader } from "ethereum-waffle";
import { BigNumber, utils, Wallet } from "ethers";
import { deployFixture } from './utils/fixture';
import { Crypto4AllAccessControls } from "../typechain";

describe('Crypto4AllAccessControls', function () {
    let admin: Wallet, minter: Wallet, anotherAccount:Wallet;
    

    let accessControls: Crypto4AllAccessControls;
    let loadFixture: ReturnType<typeof createFixtureLoader>;

    before("Create Fixture", async function () {
        [admin, minter, anotherAccount] = await (ethers as any).getSigners();
        loadFixture = createFixtureLoader([
            admin
        ]);
    });
    before("Deploy Fixture", async function () {
        ({accessControls} = await loadFixture(deployFixture));
    });
    describe('MINTER_ROLE', async function () {
        before(async function () {
            expect(await accessControls.hasAdminRole(admin.address)).to.equal(true); // creator is admin
            expect(await accessControls.hasMinterRole(minter.address)).to.equal(false);
            await accessControls.connect(admin).addMinterRole(minter.address);
        });
        it('should allow admin to add minters', async function () {
            expect(await accessControls.connect(admin).hasMinterRole(minter.address)).to.equal(true);
        });

        it('should allow admin to remove minters', async function () {
            expect(await accessControls.hasMinterRole(minter.address)).to.equal(true);
            await accessControls.connect(admin).removeMinterRole(minter.address);
            expect(await accessControls.hasMinterRole(minter.address)).to.equal(false);
        });

        it('should revert if not admin', async function () {
            await expect(
                accessControls.connect(anotherAccount).addMinterRole(minter.address)
            ).be.reverted;
        });

        it('should revert even if minter is adding already a minter', async function () {
            await expect(
                accessControls.connect(minter).addMinterRole(anotherAccount.address),
            ).be.reverted;
        });

        it('should revert if does not have the correct role', async function () {
            await accessControls.connect(admin).addMinterRole(minter.address);
            expect(await accessControls.hasMinterRole(minter.address)).to.equal(true);
            await accessControls.connect(admin).removeMinterRole(minter.address);
            await expect(
                accessControls.connect(anotherAccount).removeMinterRole(minter.address),
            ).be.reverted;
        });
    });

    describe('DEFAULT_ADMIN_ROLE', async function () {
        before(async function () {
            expect(await accessControls.hasAdminRole(admin.address)).to.equal(true); // creator is admin
            expect(await accessControls.hasAdminRole(minter.address)).to.equal(false);
            await accessControls.connect(admin).addAdminRole(minter.address);
        });

        it('should allow admin to add admin', async function () {
            expect(await accessControls.hasAdminRole(minter.address)).to.equal(true);
        });

        it('should allow admin to remove admin', async function () {
            expect(await accessControls.hasAdminRole(minter.address)).to.equal(true);
            await accessControls.connect(admin).removeAdminRole(minter.address);
            expect(await accessControls.hasAdminRole(minter.address)).to.equal(false);
        });

        it('should revert if already has minter role', async function () {
            await expect(
                accessControls.connect(anotherAccount).addAdminRole(minter.address),
            ).be.reverted;
        });

        it('should revert if does not have the correct role', async function () {
            await accessControls.connect(admin).addAdminRole(minter.address);
            expect(await accessControls.hasAdminRole(minter.address)).to.equal(true);
            await accessControls.connect(admin).removeAdminRole(minter.address);
            await expect(
                accessControls.connect(anotherAccount).removeAdminRole(minter.address),
            ).be.reverted;
        });
    });
});
