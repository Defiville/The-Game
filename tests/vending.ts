import { solidity } from 'ethereum-waffle'
import { use, expect } from 'chai'
import { ethers, waffle } from 'hardhat'
import { BigNumber, Contract } from 'ethers'

use(solidity)


describe('Deploy and test VendingMachine', () => {

    const provider = waffle.provider
    const [deployer, alice, bob] = provider.getWallets()
    const tokenId = 0
    const amountToMint = 50

    let vendingMachine: Contract
    let dvArtist: Contract
    let isla: Contract

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
        dvArtist = await DVArtist.deploy()
        await dvArtist.deployed()
        await dvArtist.mint(tokenId, amountToMint, 'ipfs.uri')
        expect(await dvArtist.balanceOf(deployer.address, tokenId)).to.equal(amountToMint)
        await dvArtist.setApprovalForAll(vendingMachine.address, true)
        const ISLA = await ethers.getContractFactory('ISLAND', deployer)
        isla = await ISLA.deploy()
        await isla.deployed()
        await isla.addMinter(deployer.address)
        const tokenDecimal = BigNumber.from(10).pow(BigNumber.from(18))
        const tokenToMint = BigNumber.from(10).mul(tokenDecimal)
        await isla.mint(alice.address, tokenToMint)
    })

    it('Sell and buy ERC1155 NFT for ETH', async()=> {
        const pricePerUnit = BigNumber.from(10).pow(BigNumber.from(18))
        const amountToBuy = 2
        await vendingMachine.createNFTSaleForETH(dvArtist.address, tokenId, amountToMint, pricePerUnit)
        expect(await dvArtist.balanceOf(vendingMachine.address, tokenId)).to.equal(amountToMint)
        await vendingMachine.connect(alice).buyNFT(0, amountToBuy, {value: pricePerUnit.mul(amountToBuy)})
        expect(await dvArtist.balanceOf(vendingMachine.address, tokenId)).to.equal(amountToMint - amountToBuy)
        await vendingMachine.cancelSale(0)
        expect(await dvArtist.balanceOf(vendingMachine.address, tokenId)).to.equal(0)
        expect(await dvArtist.balanceOf(deployer.address, tokenId)).to.equal(amountToMint - amountToBuy)
        expect(await dvArtist.balanceOf(alice.address, tokenId)).to.equal(amountToBuy)
    })

    it('Sell and buy ERC1155 NFT for ERC20', async() => {
        const amountToBuy = 2
        const pricePerUnit = BigNumber.from(10).pow(BigNumber.from(18))
        await vendingMachine.createNFTSaleForERC20(dvArtist.address, tokenId, amountToMint, isla.address, pricePerUnit)
        expect(await dvArtist.balanceOf(vendingMachine.address, tokenId)).to.equal(amountToMint)
        await isla.connect(alice).approve(vendingMachine.address, pricePerUnit.mul(amountToBuy))
        await vendingMachine.connect(alice).buyNFT(0, 2)
    })
})