import { solidity } from 'ethereum-waffle'
import { use, expect } from 'chai'
import { ethers, waffle } from 'hardhat'
import { BigNumber, Contract } from 'ethers'

use(solidity)


describe('Deploy and test RadioTips', () => {

    const provider = waffle.provider
    const [deployer, alice, bob] = provider.getWallets()
    const islaToMint = BigNumber.from(100).pow(BigNumber.from(18))
    const islaToApprove = BigNumber.from(100).pow(BigNumber.from(18))
    const islaToTip = BigNumber.from(10).pow(BigNumber.from(18))

    let radioTips: Contract
    let isla: Contract

    beforeEach(async() => {
        const RadioTips = await ethers.getContractFactory('RadioTips', deployer)
        radioTips = await RadioTips.deploy()
        await radioTips.deployed()
        const receipt = await radioTips.deployTransaction.wait()
        let gasUsage = null
        if (receipt.status === 1) {
            gasUsage = (receipt.gasUsed as BigNumber).toNumber()
        }
        expect(gasUsage).lessThan(2500000)
        const ISLA = await ethers.getContractFactory('ISLAND', deployer)
        isla = await ISLA.deploy()
        await isla.deployed()
        await isla.addMinter(deployer.address)
        await isla.mint(alice.address, islaToMint)
        await isla.connect(alice).approve(radioTips.address, islaToApprove)
        const rehab = ethers.utils.formatBytes32String('rehab')
        await radioTips.addArtistsWithRecipient([rehab], [bob.address])
    })

    it('Allow to add artist only to owner', async()=> {
        const rac = ethers.utils.formatBytes32String('rac')
        const threeLau = ethers.utils.formatBytes32String('3lau')
        const catalogWorks = ethers.utils.formatBytes32String('catalogWorks')
        const daoRecords = ethers.utils.formatBytes32String('daoRecords')
        const artistsName = [rac, threeLau, catalogWorks, daoRecords]
        await radioTips.addArtists(artistsName)
        await expect(radioTips.connect(alice).addArtists(artistsName)).to.be.revertedWith('Ownable: caller is not the owner')
        const artist1 = await radioTips.artists(1)
        expect(artist1.name).to.be.equal(artistsName[0])
    })

    it('Allow to tip existent artist by anyone but redeem it only by artist', async()=> {
        await radioTips.connect(alice).tipArtist(0, isla.address, islaToTip)
        await radioTips.connect(bob).redeemArtistTips(0, [isla.address], [islaToTip])
    })

    it('Allow to tip radio by anyone but reedem it only by owner', async()=> {
        await radioTips.connect(alice).tipRadio(isla.address, islaToTip)
        await radioTips.redeemRadioTips([isla.address], deployer.address, [islaToTip])
    })

    it('Allow to change address only by artist', async()=> {
        await radioTips.connect(bob).setArtistRecipient(0, alice.address)
    })
})