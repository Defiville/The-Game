import { solidity } from 'ethereum-waffle'
import { use, expect } from 'chai'
import { ethers, waffle } from 'hardhat'
import { BigNumber, Contract } from 'ethers'
import tokenWantABI from '../abi/tokenWant.json'

use(solidity)


describe('Deploy and test IDLEPlug', () => {

    const provider = waffle.provider
    const [deployer, alice, bob] = provider.getWallets()

    let plugIdle: Contract
    let tokenWant: Contract

    beforeEach(async() => {
        //const PlugIDLEV1 = await ethers.getContractFactory('PLUGIDLEV1', deployer)
        //plugIdle = await PlugIDLEV1.deploy()
        //await plugIdle.deployed()
        //const receipt = await plugIdle.deployTransaction.wait()
        /*let gasUsage = null
        if (receipt.status === 1) {
            gasUsage = (receipt.gasUsed as BigNumber).toNumber()
        }
        expect(gasUsage).lessThan(2500000)
        */
        //const levelCap = await plugIdle.currentLevelCap();
    })

    it('Charge Plug', async()=> {
        //const signer = await ethers.provider.getSigner("0xCA6B17f0E62373e41ae9B6B448d2601d30301d78")
        //tokenWant = new ethers.Contract('0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', tokenWantABI, signer)
        /*await network.provider.request({
            method: "hardhat_impersonateAccount",
            params: ["0xCA6B17f0E62373e41ae9B6B448d2601d30301d78"]}
        )*/
        //await tokenWant.connect(signer).approve(plugIdle.address, '0xc8');
        //await plugIdle.connect(signer).chargePlug(BigNumber.from(10).pow(BigNumber.from(18)));
    })

    it('Uncharge Plug', async()=> {
    })

    it('Rebalance', async()=> {
    })

    it('Upgrade plug level', async()=> {
    })

    it('Set rewardOut 1', async()=> {
    })

    it('Set rewardOut 2', async()=> {
    })
})