import { expect } from "chai"
import { waffle } from "hardhat"
import { PerpdexMarket } from "../../typechain"
import { createPerpdexMarketFixture } from "./fixtures"
import { BigNumber, BigNumberish, Wallet } from "ethers"
import { MockContract } from "ethereum-waffle"

describe("PerpdexMarket funding", () => {
    let loadFixture = waffle.createFixtureLoader(waffle.provider.getWallets())
    let fixture

    let market: PerpdexMarket
    let owner: Wallet
    let alice: Wallet
    let exchange: Wallet
    let priceFeed: MockContract

    beforeEach(async () => {
        fixture = await loadFixture(createPerpdexMarketFixture())
        market = fixture.perpdexMarket
        owner = fixture.owner
        alice = fixture.alice
        exchange = fixture.exchange
        priceFeed = fixture.priceFeed

        await market.connect(owner).setPoolFeeRatio(0)
        await market.connect(owner).setFundingMaxPremiumRatio(0)
        await priceFeed.mock.getPrice.returns(BigNumber.from(10).pow(18))
        await priceFeed.mock.decimals.returns(18)
    })

    describe("called with other functions", async () => {
        beforeEach(async () => {
            await market.connect(exchange).addLiquidity(10000, 10000)
            await market.connect(owner).setFundingMaxPremiumRatio(1e4)
            await priceFeed.mock.getPrice.returns(1)
        })

        it("swap", async () => {
            await expect(market.connect(exchange).swap(false, true, 2)).to.emit(market, "FundingPaid")
        })

        it("addLiquidity", async () => {
            await expect(market.connect(exchange).addLiquidity(1, 1)).to.emit(market, "FundingPaid")
        })

        it("removeLiquidity", async () => {
            await expect(market.connect(exchange).removeLiquidity(1)).to.emit(market, "FundingPaid")
        })
    })
})
