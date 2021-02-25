import { solidity } from 'ethereum-waffle'
import { use, expect } from 'chai'
import { ethers, waffle } from 'hardhat'
import { BigNumber, Contract } from 'ethers'

use(solidity)


describe('Deploy and test VendingMachine', () => {

    const provider = waffle.provider
    const [deployer, alice, bob] = provider.getWallets()

    let vendingMachine: Contract
    let dvArtist: Contract

    beforeEach(async() => {
        const VendingMachine = await ethers.getContractFactory('VendingMachine', deployer)
        vendingMachine = await VendingMachine.deploy()
        await vendingMachine.deployed()
        const receipt = await vendingMachine.deployTransaction.wait()
        let gasUsage = null
        if (receipt.status === 1) {
            gasUsage = (receipt.gasUsed as BigNumber).toNumber()
        }
        expect(gasUsage).lessThan(2000000)

        const DVArtist = await ethers.getContractFactory('DVArtist', deployer)
        dvArtist = await DVArtist.deploy('dv.artist', 'DVArt', 'ipfs:/')
        await dvArtist.deployed()
    })

    it('sell and buy ERC1155 NFT via vending', async()=> {
        const tokenId = 0
        const amount = 50
        const tokenWant = '0x68adb858a056496b1331E9C15F03Ef54C7717E7e' 
        const pricePerUnit = 10
        await dvArtist.mint(tokenId, amount, 'ipfs.uri')
        expect(await dvArtist.balanceOf(deployer.address, tokenId)).to.equal(amount)
        await dvArtist.setApprovalForAll(vendingMachine.address, true)
        await vendingMachine.erc1155Sale(dvArtist.address, tokenId, amount, tokenWant, pricePerUnit)
        expect(await dvArtist.balanceOf(vendingMachine.address, tokenId)).to.equal(amount)
        //await vendingMachine.buyNFT(0, 1)
    })

    /*it('sell ERC1155 to vending', async()=> {

    })*/
})