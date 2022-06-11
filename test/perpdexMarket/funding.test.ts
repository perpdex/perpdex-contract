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

    describe("called with other functions. positive funding", () => {
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
            const cumQuotePerLiquidityX96 = BigNumber.from("7922816251426433759354395")

            await expect(market.connect(exchange).swap(false, true, 2, false))
                .to.emit(market, "FundingPaid")
                .withArgs(
                    expectedFundingRate,
                    60,
                    Q96.mul(1e4).div(1e6),
                    BigNumber.from("79251933340101200581120771203"),
                    0,
                    cumQuotePerLiquidityX96,
                )

            const poolInfo = await market.poolInfo()
            expect(poolInfo.cumQuotePerLiquidityX96).to.eq(cumQuotePerLiquidityX96)
        })

        it("addLiquidity", async () => {
            const cumQuotePerLiquidityX96 = BigNumber.from("7922024049021531606193775")

            await expect(market.connect(exchange).addLiquidity(1, 1))
                .to.emit(market, "FundingPaid")
                .withArgs(expectedFundingRate, 60, Q96.mul(1e4).div(1e6), Q96, 0, cumQuotePerLiquidityX96)

            const poolInfo = await market.poolInfo()
            expect(poolInfo.cumQuotePerLiquidityX96).to.eq(cumQuotePerLiquidityX96)
        })

        it("removeLiquidity", async () => {
            const cumQuotePerLiquidityX96 = BigNumber.from("7923608612287662525606955")

            await expect(market.connect(exchange).removeLiquidity(1))
                .to.emit(market, "FundingPaid")
                .withArgs(expectedFundingRate, 60, Q96.mul(1e4).div(1e6), Q96, 0, cumQuotePerLiquidityX96)

            const poolInfo = await market.poolInfo()
            expect(poolInfo.cumQuotePerLiquidityX96).to.eq(cumQuotePerLiquidityX96)
        })
    })

    describe("FundingPaid event. negative funding", () => {
        const expectedFundingRate = Q96.div(100).mul(60).div(3600).mul(-1)

        beforeEach(async () => {
            await market.connect(exchange).addLiquidity(10000, 10000)
            await market.connect(owner).setFundingMaxPremiumRatio(1e4)
            await priceFeed.mock.getPrice.returns(BigNumber.from(10).pow(18).mul(2))

            const currentTimestamp = await getTimestamp()
            await market.setFundingInfo({
                prevIndexPriceBase: BigNumber.from(10).pow(18),
                prevIndexPriceQuote: 1,
                prevIndexPriceTimestamp: currentTimestamp + 1000,
            })
            await setNextTimestamp(currentTimestamp + 1000 + 60)
        })

        it("swap", async () => {
            const cumBasePerLiquidityX96 = BigNumber.from("7922816251426433759354395")

            await expect(market.connect(exchange).swap(false, true, 2, false))
                .to.emit(market, "FundingPaid")
                .withArgs(
                    expectedFundingRate,
                    60,
                    Q96.mul(1e4).div(1e6).mul(-1),
                    BigNumber.from("79251933340101200581120771203"),
                    cumBasePerLiquidityX96,
                    0,
                )

            const poolInfo = await market.poolInfo()
            expect(poolInfo.cumBasePerLiquidityX96).to.eq(cumBasePerLiquidityX96)
        })
    })

    describe("price not changed. share price changed.", () => {
        let priceBefore, sharePriceBefore

        beforeEach(async () => {
            // sufficiently large pool to minimize swap impact
            await market.connect(exchange).addLiquidity(Q96, Q96)
            await market.connect(owner).setFundingMaxPremiumRatio(1e4)

            priceBefore = await market.getMarkPriceX96()
            sharePriceBefore = await market.getShareMarkPriceX96()

            const currentTimestamp = await getTimestamp()
            await market.setFundingInfo({
                prevIndexPriceBase: BigNumber.from(10).pow(18),
                prevIndexPriceQuote: 1,
                prevIndexPriceTimestamp: currentTimestamp + 1000,
            })
            await setNextTimestamp(currentTimestamp + 1000 + 3600)
        })

        it("positive funding", async () => {
            await priceFeed.mock.getPrice.returns(BigNumber.from(10).pow(18).div(2))

            await expect(market.connect(exchange).swap(false, true, 2, false)).to.emit(market, "FundingPaid")

            const priceAfter = await market.getMarkPriceX96()
            const priceRange = priceBefore.div(BigNumber.from(10).pow(18))
            expect(priceAfter).to.be.gt(priceBefore.sub(priceRange))
            expect(priceAfter).to.be.lt(priceBefore.add(priceRange))

            const sharePriceAfter = await market.getShareMarkPriceX96()
            expect(sharePriceAfter).to.be.gt(sharePriceBefore.sub(sharePriceBefore.mul(11).div(1000)))
            expect(sharePriceAfter).to.be.lt(sharePriceBefore.sub(sharePriceBefore.mul(9).div(1000)))
        })

        it("negative funding", async () => {
            await priceFeed.mock.getPrice.returns(BigNumber.from(10).pow(18).mul(2))

            await expect(market.connect(exchange).swap(false, true, 2, false)).to.emit(market, "FundingPaid")

            const priceAfter = await market.getMarkPriceX96()
            const priceError = priceBefore.div(BigNumber.from(10).pow(18))
            expect(priceAfter).to.be.gt(priceBefore.sub(priceError))
            expect(priceAfter).to.be.lt(priceBefore.add(priceError))

            const sharePriceAfter = await market.getShareMarkPriceX96()
            expect(sharePriceAfter).to.be.gt(sharePriceBefore.add(sharePriceBefore.mul(9).div(1000)))
            expect(sharePriceAfter).to.be.lt(sharePriceBefore.add(sharePriceBefore.mul(11).div(1000)))
        })
    })

    describe("total pool assets not changed", () => {
        const totalBase = poolInfo => {
            return poolInfo.base.add(poolInfo.totalLiquidity.mul(poolInfo.cumBasePerLiquidityX96).div(Q96))
        }
        const totalQuote = poolInfo => {
            return poolInfo.quote.add(poolInfo.totalLiquidity.mul(poolInfo.cumQuotePerLiquidityX96).div(Q96))
        }

        let poolInfoBefore

        beforeEach(async () => {
            // sufficiently large pool to minimize swap impact
            await market.connect(exchange).addLiquidity(Q96, Q96)
            await market.connect(owner).setFundingMaxPremiumRatio(1e4)

            poolInfoBefore = await market.poolInfo()

            const currentTimestamp = await getTimestamp()
            await market.setFundingInfo({
                prevIndexPriceBase: BigNumber.from(10).pow(18),
                prevIndexPriceQuote: 1,
                prevIndexPriceTimestamp: currentTimestamp + 1000,
            })
            await setNextTimestamp(currentTimestamp + 1000 + 3600)
        })

        it("positive funding", async () => {
            await priceFeed.mock.getPrice.returns(BigNumber.from(10).pow(18).div(2))

            await expect(market.connect(exchange).swap(false, true, 2, false)).to.emit(market, "FundingPaid")

            const poolInfoAfter = await market.poolInfo()
            expect(totalBase(poolInfoAfter)).to.be.closeTo(totalBase(poolInfoBefore), 100)
            expect(totalQuote(poolInfoAfter)).to.be.closeTo(totalQuote(poolInfoBefore), 100)
        })

        it("negative funding", async () => {
            await priceFeed.mock.getPrice.returns(BigNumber.from(10).pow(18).mul(2))

            await expect(market.connect(exchange).swap(false, true, 2, false)).to.emit(market, "FundingPaid")

            const poolInfoAfter = await market.poolInfo()
            expect(totalBase(poolInfoAfter)).to.be.closeTo(totalBase(poolInfoBefore), 100)
            expect(totalQuote(poolInfoAfter)).to.be.closeTo(totalQuote(poolInfoBefore), 100)
        })
    })
})
