import { solidity } from 'ethereum-waffle'
import { use, expect } from 'chai'
import { network, ethers, waffle } from 'hardhat'
import { BigNumber, Contract } from 'ethers'
import tokenWantABI from '../abi/tokenWant.json'

use(solidity)


describe('Deploy and test Radio Subscription', () => {

    const provider = waffle.provider
    const [deployer, alice, bob] = provider.getWallets()

    let radio: Contract
    let tokenWant: Contract
    let tokenStrategy: Contract

    beforeEach(async() => {
        const Radio = await ethers.getContractFactory('RadioSubscription', deployer)
        radio = await Radio.deploy()
        await radio.deployed()
        const receipt = await radio.deployTransaction.wait()
        let gasUsage = null
        if (receipt.status === 1) {
            gasUsage = (receipt.gasUsed as BigNumber).toNumber()
        }
        expect(gasUsage).lessThan(2500000)
    })

    it('Subscribe to Radio', async()=> {
    })

    it('Increase subscription', async()=> {
    })

    it('Set Redeem for Artists', async()=> {
    })

    it('Artist redeem', async()=> {
    })

    it('Earn', async()=> {
    })

    it('Tip', async()=> {
    })
})