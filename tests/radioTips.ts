import { solidity } from 'ethereum-waffle'
import { use, expect } from 'chai'
import { ethers, waffle } from 'hardhat'
import { BigNumber, Contract } from 'ethers'

use(solidity)


describe('Deploy and test RadioTips', () => {

    const provider = waffle.provider
    const [deployer, alice, rehab, rac] = provider.getWallets()
    const islaToMint = BigNumber.from(100).pow(BigNumber.from(18))
    const islaToApprove = BigNumber.from(100).pow(BigNumber.from(18))
    const islaToTip = BigNumber.from(10).pow(BigNumber.from(18))
    const ETH = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';

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
        const rehabName = 'rehab'
        const racName = 'rac'
        await radioTips.addArtistsWithRecipient([rehabName], [rehab.address])
        await radioTips.addArtists([racName])
    })

    it('Allow to add artist only to owner', async()=> {
        const threeLau = '3lau'
        const catalogWorks = 'catalogWorks'
        const daoRecords = 'daoRecords'
        const artistsName = [threeLau, catalogWorks, daoRecords]
        await radioTips.addArtists(artistsName)
        await expect(radioTips.connect(alice).addArtists(artistsName)).to.be.revertedWith('Ownable: caller is not the owner')
        const artist3 = await radioTips.artists(2)
        expect(artist3.name).to.be.equal(artistsName[0])
    })

    it('Disallow to add artist with empty name', async() => {
        const noName = ''
        await expect(radioTips.addArtists([noName])).to.be.revertedWith('Empty Name')
    })

    it('Allow to tip existent artist with ERC20 by anyone but redeem it only by artist', async()=> {
        await radioTips.connect(alice).tipArtist(0, isla.address, islaToTip)
        await radioTips.connect(rehab).redeemArtistTips(0, [isla.address], [islaToTip])
    })

    it('Allow to tip existent artist with ETH by anyone but redeem it only by artist', async()=> {
        await radioTips.connect(alice).tipArtist(0, ETH, islaToTip, {value:islaToTip})
        await radioTips.connect(rehab).redeemArtistTips(0, [ETH],    [islaToTip])
    })

    it('Allow to tip existent artists with ETH twice', async()=> {
        await radioTips.connect(alice).tipArtists([0,0], [ETH, ETH], [islaToTip, islaToTip], {value:islaToTip.mul(2)})
        await radioTips.connect(rehab).redeemArtistTips(0, [ETH], [islaToTip])
        const ETHtip = await radioTips.getArtistTip(0, ETH)
        expect(ETHtip).to.be.equal(islaToTip)

    })

    it('Allow to tips radio by anyone but reedem these only by owner', async()=> {
        await radioTips.connect(alice).tipRadio(isla.address, islaToTip)
        await radioTips.connect(alice).tipRadio(ETH, islaToTip, {value:islaToTip})
        await expect(radioTips.connect(alice).redeemRadioTips(
            [isla.address], 
            [islaToTip],
            deployer.address
        )).to.be.revertedWith('Ownable: caller is not the owner')
        await radioTips.redeemRadioTips([isla.address, ETH], [islaToTip, islaToTip], deployer.address)
    })

    it('Allow to initialize recipient only by owner, once', async()=> {
        await expect(
            radioTips.connect(alice).initializeArtistRecipient(0, alice.address)
        ).to.be.revertedWith('Ownable: caller is not the owner')
        await radioTips.initializeArtistRecipient(1, rac.address)
        await expect(
            radioTips.initializeArtistRecipient(1, rac.address)
        ).to.be.revertedWith('Already initialized')

    })

    it('Allow to change address only by artist', async()=> {
        await radioTips.connect(rehab).setArtistRecipient(0, alice.address)
    })
})