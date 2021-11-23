const { BN, constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const { ZERO_ADDRESS } = constants;
const web3 = require('web3');

const { expect } = require('chai');

const Crypto4AllAccessControls = artifacts.require('Crypto4AllAccessControls');
const Crypto4AllNFT = artifacts.require('Crypto4AllNFT');

contract('Core ERC721 tests for Crypto4AllNFT', function ([admin, minter, owner, smart_contract, creator, random]) {
    const randomURI = 'rand';

    const TOKEN_ONE_ID = new BN('1');

    beforeEach(async () => {
        this.accessControls = await Crypto4AllAccessControls.new({from: admin});
        await this.accessControls.addMinterRole(admin, {from: admin});
        await this.accessControls.addMinterRole(minter, {from: admin});

        this.token = await Crypto4AllNFT.new(
          this.accessControls.address,
          {from: admin}
        );

    });

    describe('Reverts', () => {
        describe('Minting', () => {
            it('When sender does not have a ADMIN or MINTER', async () => {
                await expectRevert(
                    this.token.mint(minter, randomURI, creator, {from: random}),
                    "Crypto4AllNFT.mint: Sender must have the admin or minter role"
                );
            });

            it('When token URI is empty', async () => {
                await expectRevert(
                    this.token.mint(minter, '', creator, {from: minter}),
                    "Crypto4AllNFT._assertMintingParamsValid: Token URI is empty"
                );
            });

            it('When creator is address ZERO', async () => {
                await expectRevert(
                    this.token.mint(minter, randomURI, ZERO_ADDRESS, {from: minter}),
                    "Crypto4AllNFT._assertMintingParamsValid: creator is zero address"
                );
            });
        });

        describe('Admin function', () => {
            it('When sender does not have a DEFAULT_ADMIN_ROLE role', async () => {
                await this.token.mint(minter, randomURI, creator, {from: minter});
                await expectRevert(
                    this.token.setTokenURI('1', randomURI, {from: minter}),
                    "Crypto4AllNFT.setTokenURI: Sender must have the admin role"
                );
            });
        });
    });

    describe('Minting validation', () => {
        it('Correctly stored the creator', async () => {
            await this.token.mint(owner, randomURI, creator, {from: minter});
            expect(await this.token.exists(TOKEN_ONE_ID)).to.be.true;
            expect(await this.token.postCreators(TOKEN_ONE_ID)).to.be.equal(creator);
        });
    });

    describe('Updating access controls', () => {
       it('Can update access controls as admin', async () => {
           const currentAccessControlsAddress = await this.token.accessControls();
           await this.token.updateAccessControls(smart_contract, {from: admin});
           expect(await this.token.accessControls()).to.be.equal(smart_contract);
           expect(await this.token.accessControls()).to.not.equal(currentAccessControlsAddress);
       });

       it('Reverts when sender is not admin', async () => {
         await expectRevert(
           this.token.updateAccessControls(smart_contract, {from: random}),
           "Crypto4AllNFT.updateAccessControls: Sender must be admin"
         );
       });
    });
})
