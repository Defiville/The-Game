import { solidity } from 'ethereum-waffle'
import { use, expect } from 'chai'
import { ethers, waffle } from 'hardhat'
import { BigNumber, Contract } from 'ethers'

use(solidity)


describe('Deploy and test DV-Artist NFT', () => {

    const provider = waffle.provider
    const [deployer, alice, bob] = provider.getWallets()

    let dvArtist: Contract

    beforeEach(async() => {
        const DVArtist = await ethers.getContractFactory('DVArtist', deployer)
        dvArtist = await DVArtist.deploy()
        await dvArtist.deployed()
        const receipt = await dvArtist.deployTransaction.wait()
        let gasUsage = null
        if (receipt.status === 1) {
            gasUsage = (receipt.gasUsed as BigNumber).toNumber()
        }
        expect(gasUsage).lessThan(1920000)
    })

    it('Check DV-Artist NFT parameter', async () => {
        expect(await dvArtist.name()).to.equal('Defiville Artist Collection')
        expect(await dvArtist.symbol()).to.equal('DVART')
        expect(await dvArtist.tokenURIPrefix()).to.equal('ipfs:/')
    })

    it('Allow only owner to mint a new NFT', async()=> {
        const nft = await dvArtist.mint(0, 50, 'ipfs.uri')
        expect(await dvArtist.balanceOf(deployer.address, 0)).to.equal(50)
        await expect(dvArtist.connect(alice).mint(1, 100, 'ipfs.uri')).to.be.revertedWith('Ownable: caller is not the owner')
        const tokenURIPrefix = await dvArtist.tokenURIPrefix()
        expect(await dvArtist.uri(0)).to.equal(tokenURIPrefix + 'ipfs.uri')
        const data = new Uint8Array(0)
        await dvArtist.safeTransferFrom(deployer.address, alice.address, 0, 10, data)
        expect(await dvArtist.balanceOf(deployer.address, 0)).to.equal(40)
        expect(await dvArtist.balanceOf(alice.address, 0)).to.equal(10)
    })

    it('Transfer ownership', async() => {
        await dvArtist.transferOwnership(alice.address)
        await dvArtist.connect(alice).mint(0, 100, 'ipfs.uri')
        expect(await dvArtist.balanceOf(alice.address, 0)).to.equal(100)
        await expect(dvArtist.connect(deployer).mint(1, 100, 'ipfs.uri')).to.be.revertedWith('Ownable: caller is not the owner')
    })
})