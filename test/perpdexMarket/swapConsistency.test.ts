import { expect } from "chai"
import { waffle } from "hardhat"
import { PerpdexMarket } from "../../typechain"
import { createPerpdexMarketFixture } from "./fixtures"
import { BigNumber, BigNumberish, Wallet } from "ethers"
import { MockContract } from "ethereum-waffle"

describe("PerpdexMarket swap consistency", () => {
    let loadFixture = waffle.createFixtureLoader(waffle.provider.getWallets())
    let fixture

    let market: PerpdexMarket
    let owner: Wallet
    let alice: Wallet
    let exchange: Wallet
    let priceFeed: MockContract
    const initialPoolAmount = BigNumber.from(10).pow(18)

    beforeEach(async () => {
        fixture = await loadFixture(createPerpdexMarketFixture())
        market = fixture.perpdexMarket
        owner = fixture.owner
        alice = fixture.alice
        exchange = fixture.exchange
        priceFeed = fixture.priceFeed

        await market.connect(owner).setPoolFeeRatio(0)
        await market.connect(owner).setFundingMaxPremiumRatio(0)
        await market.connect(owner).setPriceLimitConfig({
            normalOrderRatio: 1e5,
            liquidationRatio: 2e5,
            emaNormalOrderRatio: 5e5,
            emaLiquidationRatio: 5e5,
            emaSec: 0,
        })
    })
    ;[0, 1e4, 5e4].forEach(fee => {
        ;[false, true].forEach(isBaseToQuote => {
            ;[false, true].forEach(isExactInput => {
                ;[false, true].forEach(isLiquidation => {
                    describe(`fee ${fee} isBaseToQuote ${isBaseToQuote} isExactInput ${isExactInput} isLiquidation ${isLiquidation}`, () => {
                        beforeEach(async () => {
                            await market.connect(exchange).addLiquidity(initialPoolAmount, initialPoolAmount)
                            await market.connect(owner).setPoolFeeRatio(fee)
                        })

                        it("swap revert condition with maxSwap", async () => {
                            const amount = await market.maxSwap(isBaseToQuote, isExactInput, isLiquidation)

                            const res2 = market
                                .connect(exchange)
                                .swap(isBaseToQuote, isExactInput, amount.add(1), isLiquidation)
                            await expect(res2).to.reverted

                            const res = market
                                .connect(exchange)
                                .swap(isBaseToQuote, isExactInput, amount, isLiquidation)
                            await expect(res).not.to.reverted
                        })

                        it("previewSwap revert condition with maxSwap", async () => {
                            const amount = await market.maxSwap(isBaseToQuote, isExactInput, isLiquidation)

                            const res2 = market.previewSwap(isBaseToQuote, isExactInput, amount.add(1), isLiquidation)
                            await expect(res2).to.reverted

                            const res = market.previewSwap(isBaseToQuote, isExactInput, amount, isLiquidation)
                            await expect(res).not.to.reverted
                        })

                        it("swap and previewSwap", async () => {
                            const priceBefore = await market.getShareMarkPriceX96()
                            const amount = await market.maxSwap(isBaseToQuote, isExactInput, isLiquidation)

                            const previewOppositeAmount = await market.previewSwap(
                                isBaseToQuote,
                                isExactInput,
                                amount,
                                isLiquidation,
                            )

                            await expect(
                                market.connect(exchange).swap(isBaseToQuote, isExactInput, amount, isLiquidation),
                            )
                                .to.emit(market, "Swapped")
                                .withArgs(isBaseToQuote, isExactInput, amount, previewOppositeAmount)

                            const poolInfo = await market.poolInfo()
                            if (isExactInput) {
                                if (isBaseToQuote) {
                                    expect(poolInfo.base).to.eq(BigNumber.from(initialPoolAmount).add(amount))
                                    expect(poolInfo.quote).to.eq(
                                        BigNumber.from(initialPoolAmount).sub(previewOppositeAmount),
                                    )
                                } else {
                                    expect(poolInfo.base).to.eq(
                                        BigNumber.from(initialPoolAmount).sub(previewOppositeAmount),
                                    )
                                    expect(poolInfo.quote).to.eq(BigNumber.from(initialPoolAmount).add(amount))
                                }
                            } else {
                                if (isBaseToQuote) {
                                    expect(poolInfo.base).to.eq(
                                        BigNumber.from(initialPoolAmount).add(previewOppositeAmount),
                                    )
                                    expect(poolInfo.quote).to.eq(BigNumber.from(initialPoolAmount).sub(amount))
                                } else {
                                    expect(poolInfo.base).to.eq(BigNumber.from(initialPoolAmount).sub(amount))
                                    expect(poolInfo.quote).to.eq(
                                        BigNumber.from(initialPoolAmount).add(previewOppositeAmount),
                                    )
                                }
                            }

                            const priceAfter = await market.getShareMarkPriceX96()
                            const priceLimitRatio = isLiquidation ? 2e5 : 1e5
                            const priceRange = priceBefore.mul(priceLimitRatio).div(1e6)
                            const priceBound = isBaseToQuote ? priceBefore.sub(priceRange) : priceBefore.add(priceRange)
                            const priceBoundError = priceBound.div(1e15)
                            expect(priceAfter).to.be.gt(priceBound.sub(priceBoundError))
                            expect(priceAfter).to.be.lt(priceBound.add(priceBoundError))
                        })
                    })
                })
            })
        })
    })
})
