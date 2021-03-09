import { solidity } from 'ethereum-waffle'
import { use, expect } from 'chai'
import { ethers, waffle } from 'hardhat'
import { BigNumber, Contract } from 'ethers'

use(solidity)


describe('Deploy and test IDLEPlug', () => {

    const provider = waffle.provider
    const [deployer, alice, bob] = provider.getWallets()

    let plugIdle: Contract
    let tokenWant: Contract
    let tokenStrategy: Contract

    beforeEach(async() => {
        const PlugIDLEV1 = await ethers.getContractFactory('PLUGIDLEV1', deployer)
        plugIdle = await PlugIDLEV1.deploy()
        await plugIdle.deployed()
        const receipt = await plugIdle.deployTransaction.wait()
        let gasUsage = null
        if (receipt.status === 1) {
            gasUsage = (receipt.gasUsed as BigNumber).toNumber()
        }
        expect(gasUsage).lessThan(2000000)

        await plugIdle.activatePlug()
        const levelCap = await plugIdle.currentLevelCap();
        console.log(levelCap);

        await expect(plugIdle.activatePlug()).to.be.revertedWith('Plug already activated')

        const price = await plugIdle.plugTotalAmount()
        
    })

    it('Charge Plug', async()=> {
    })
})