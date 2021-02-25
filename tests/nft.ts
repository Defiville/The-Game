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
        dvArtist = await DVArtist.deploy('dv.artist', 'DVArt', 'ipfs:/')
        await dvArtist.deployed()
        const receipt = await dvArtist.deployTransaction.wait()
        let gasUsage = null
        if (receipt.status === 1) {
            gasUsage = (receipt.gasUsed as BigNumber).toNumber()
        }
        expect(gasUsage).lessThan(2000000)
    })

    it('Check DV-Artist NFT parameter', async () => {
        expect(await dvArtist.name()).to.equal('dv.artist')
        expect(await dvArtist.symbol()).to.equal('DVArt')
    })

    it('allow only owner to mint a new NFT', async()=> {
        const nft = await dvArtist.mint(0, 50, 'ipfs.uri')
        expect(await dvArtist.balanceOf(deployer.address, 0)).to.equal(50)
        await expect(dvArtist.connect(alice).mint(1, 100, 'ipfs.uri')).to.be.revertedWith('Ownable: caller is not the owner')
    })
})