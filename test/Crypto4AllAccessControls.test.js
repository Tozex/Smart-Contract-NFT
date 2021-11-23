const {expectRevert} = require('@openzeppelin/test-helpers');

const {expect} = require('chai');

const Crypto4AllAccessControls = artifacts.require('Crypto4AllAccessControls');
const onlyAdminRoleErrorGrantMsg = "AccessControl: sender must be an admin to grant";
const onlyAdminRoleErrorRevokeMsg = "AccessControl: sender must be an admin to revoke";

contract('Crypto4AllAccessControls', (accounts) => {
    const [admin, minter, smart_contract, anotherAccount] = accounts;

    beforeEach(async function () {
        this.accessControls = await Crypto4AllAccessControls.new({from: admin});
    });

    describe('MINTER_ROLE', async function () {
        beforeEach(async function () {
            expect(await this.accessControls.hasAdminRole(admin)).to.equal(true); // creator is admin
            expect(await this.accessControls.hasMinterRole(minter)).to.equal(false);
            await this.accessControls.addMinterRole(minter, {from: admin});
        });

        it('should allow admin to add minters', async function () {
            expect(await this.accessControls.hasMinterRole(minter)).to.equal(true);
        });

        it('should allow admin to remove minters', async function () {
            expect(await this.accessControls.hasMinterRole(minter)).to.equal(true);
            await this.accessControls.removeMinterRole(minter, {from: admin});
            expect(await this.accessControls.hasMinterRole(minter)).to.equal(false);
        });

        it('should revert if not admin', async function () {
            await expectRevert(
                this.accessControls.addMinterRole(minter, {from: anotherAccount}),
                onlyAdminRoleErrorGrantMsg
            );
        });

        it('should revert even if minter is adding already a minter', async function () {
            await expectRevert(
                this.accessControls.addMinterRole(anotherAccount, {from: minter}),
                onlyAdminRoleErrorGrantMsg
            );
        });

        it('should revert if does not have the correct role', async function () {
            expect(await this.accessControls.hasMinterRole(minter)).to.equal(true);
            await this.accessControls.removeMinterRole(minter, {from: admin});
            await expectRevert(
                this.accessControls.removeMinterRole(minter, {from: anotherAccount}),
                onlyAdminRoleErrorRevokeMsg
            );
        });
    });

    describe('DEFAULT_ADMIN_ROLE', async function () {
        beforeEach(async function () {
            expect(await this.accessControls.hasAdminRole(admin)).to.equal(true); // creator is admin
            expect(await this.accessControls.hasAdminRole(minter)).to.equal(false);
            await this.accessControls.addAdminRole(minter, {from: admin});
        });

        it('should allow admin to add admin', async function () {
            expect(await this.accessControls.hasAdminRole(minter)).to.equal(true);
        });

        it('should allow admin to remove admin', async function () {
            expect(await this.accessControls.hasAdminRole(minter)).to.equal(true);
            await this.accessControls.removeAdminRole(minter, {from: admin});
            expect(await this.accessControls.hasAdminRole(minter)).to.equal(false);
        });

        it('should revert if already has minter role', async function () {
            await expectRevert(
                this.accessControls.addAdminRole(minter, {from: anotherAccount}),
                onlyAdminRoleErrorGrantMsg
            );
        });

        it('should revert if does not have the correct role', async function () {
            expect(await this.accessControls.hasAdminRole(minter)).to.equal(true);
            await this.accessControls.removeAdminRole(minter, {from: admin});
            await expectRevert(
                this.accessControls.removeAdminRole(minter, {from: anotherAccount}),
                onlyAdminRoleErrorRevokeMsg
            );
        });
    });
});
