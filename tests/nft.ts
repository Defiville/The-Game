import { solidity } from 'ethereum-waffle'
import { use, expect } from 'chai'
import { ethers, waffle } from 'hardhat'
import { BigNumber, Contract } from 'ethers'

use(solidity)


describe('Deploy and test DV-Artist NFT', () => {

    const provider = waffle.provider
    const [, deployer, coordinator] = provider.getWallets()

    let dvArtist: Contract;

    beforeEach(async() => {
        const DVArtist = await ethers.getContractFactory('DVArtist')
        dvArtist = await DVArtist.deploy("dv.artist", "DVArt", "ipfs:/")
        await dvArtist.deployed()
        const receipt = await dvArtist.deployTransaction.wait()
        let gasUsage = null;
        if (receipt.status === 1) {
            gasUsage = (receipt.gasUsed as BigNumber).toNumber()
        }
        expect(gasUsage).lessThan(2000000)
    })

    it('Check DV-Artist NFT parameter', async () => {
        expect(await dvArtist.name()).to.equal("dv.artist")
        expect(await dvArtist.symbol()).to.equal("DVArt")
    })

    /*it('allow only owner to mint a new NFT', async()=> {

    })

    it('allow whitelist to sell NFT via vending machine', async() => {

    })*/

})