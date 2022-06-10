import { expect } from "chai"
import { waffle } from "hardhat"
import { TestPerpdexMarket } from "../../typechain"
import { createPerpdexMarketFixture } from "./fixtures"
import { BigNumber, BigNumberish, Wallet } from "ethers"
import { MockContract } from "ethereum-waffle"
import { getTimestamp, setNextTimestamp } from "../helper/time"

describe("PerpdexMarket funding", () => {
    let loadFixture = waffle.createFixtureLoader(waffle.provider.getWallets())
    let fixture

    let market: TestPerpdexMarket
    let owner: Wallet
    let alice: Wallet
    let exchange: Wallet
    let priceFeed: MockContract

    const Q96 = BigNumber.from(2).pow(96)

    beforeEach(async () => {
        fixture = await loadFixture(createPerpdexMarketFixture())
        market = fixture.perpdexMarket
        owner = fixture.owner
        alice = fixture.alice
        exchange = fixture.exchange
        priceFeed = fixture.priceFeed

        await market.connect(owner).setPoolFeeRatio(0)
        await market.connect(owner).setFundingMaxPremiumRatio(0)
        await market.connect(owner).setFundingRolloverSec(3600)
        await priceFeed.mock.getPrice.returns(BigNumber.from(10).pow(18))
        await priceFeed.mock.decimals.returns(18)
    })

    describe("called with other functions", () => {
        const expectedFundingRate = Q96.div(100).mul(60).div(3600)

        beforeEach(async () => {
            await market.connect(exchange).addLiquidity(10000, 10000)
            await market.connect(owner).setFundingMaxPremiumRatio(1e4)
            await priceFeed.mock.getPrice.returns(1)

            const currentTimestamp = await getTimestamp()

            await market.setFundingInfo({
                prevIndexPriceBase: BigNumber.from(10).pow(18),
                prevIndexPriceQuote: 1,
                prevIndexPriceTimestamp: currentTimestamp + 1000,
            })

            await setNextTimestamp(currentTimestamp + 1000 + 60)
        })

        it("swap", async () => {
            await expect(market.connect(exchange).swap(false, true, 2, false))
                .to.emit(market, "FundingPaid")
                .withArgs(
                    expectedFundingRate,
                    60,
                    Q96.mul(1e4).div(1e6),
                    BigNumber.from("79251933340101200581120771203"),
                )
        })

        it("addLiquidity", async () => {
            await expect(market.connect(exchange).addLiquidity(1, 1))
                .to.emit(market, "FundingPaid")
                .withArgs(expectedFundingRate, 60, Q96.mul(1e4).div(1e6), Q96)
        })

        it("removeLiquidity", async () => {
            await expect(market.connect(exchange).removeLiquidity(1))
                .to.emit(market, "FundingPaid")
                .withArgs(expectedFundingRate, 60, Q96.mul(1e4).div(1e6), Q96)
        })
    })
})
