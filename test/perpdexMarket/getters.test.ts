import { expect } from "chai"
import { waffle } from "hardhat"
import { TestPerpdexMarket } from "../../typechain"
import { createPerpdexMarketFixture } from "./fixtures"
import { BigNumber, Wallet } from "ethers"

describe("PerpdexMarket getters", () => {
    let loadFixture = waffle.createFixtureLoader(waffle.provider.getWallets())
    let fixture

    let market: TestPerpdexMarket

    beforeEach(async () => {
        fixture = await loadFixture(createPerpdexMarketFixture())
        market = fixture.perpdexMarket
    })

    describe("getMarkPriceX96 and getShareMarkPriceX96", () => {
        ;[
            {
                title: "empty",
                base: 0,
                quote: 0,
                baseBalancePerShareX96: BigNumber.from(2).pow(96),
                markPriceX96: 0,
                shareMarkPriceX96: 0,
            },
            {
                title: "normal",
                base: 1,
                quote: 1,
                baseBalancePerShareX96: BigNumber.from(2).pow(96),
                markPriceX96: BigNumber.from(2).pow(96),
                shareMarkPriceX96: BigNumber.from(2).pow(96),
            },
            {
                title: "base quote",
                base: 4,
                quote: 5,
                baseBalancePerShareX96: BigNumber.from(2).pow(96),
                markPriceX96: BigNumber.from(2).pow(96).mul(5).div(4),
                shareMarkPriceX96: BigNumber.from(2).pow(96).mul(5).div(4),
            },
            {
                title: "baseBalancePerShareX96",
                base: 1,
                quote: 1,
                baseBalancePerShareX96: BigNumber.from(2).pow(96).div(2),
                markPriceX96: BigNumber.from(2).pow(96).mul(2),
                shareMarkPriceX96: BigNumber.from(2).pow(96),
            },
        ].forEach(test => {
            it(test.title, async () => {
                await market.setPoolInfo({
                    base: test.base,
                    quote: test.quote,
                    totalLiquidity: 0,
                    cumBasePerLiquidityX96: 0,
                    cumQuotePerLiquidityX96: 0,
                    baseBalancePerShareX96: test.baseBalancePerShareX96,
                })
                expect(await market.getMarkPriceX96()).to.eq(test.markPriceX96)
                expect(await market.getShareMarkPriceX96()).to.eq(test.shareMarkPriceX96)
            })
        })
    })

    describe("getLiquidityValue", () => {
        ;[
            {
                title: "normal",
                base: 1,
                quote: 1,
                totalLiquidity: 1,
                liquidity: 1,
                outputBase: 1,
                outputQuote: 1,
            },
            {
                title: "partial",
                base: 50,
                quote: 100,
                totalLiquidity: 10,
                liquidity: 3,
                outputBase: 15,
                outputQuote: 30,
            },
            {
                title: "larger",
                base: 1,
                quote: 1,
                totalLiquidity: 1,
                liquidity: 2,
                outputBase: 2,
                outputQuote: 2,
            },
            {
                title: "empty pool",
                base: 0,
                quote: 0,
                totalLiquidity: 0,
                liquidity: 1,
                revertedWith: "",
            },
        ].forEach(test => {
            it(test.title, async () => {
                await market.setPoolInfo({
                    base: test.base,
                    quote: test.quote,
                    totalLiquidity: test.totalLiquidity,
                    cumBasePerLiquidityX96: 0,
                    cumQuotePerLiquidityX96: 0,
                    baseBalancePerShareX96: 0,
                })
                if (test.revertedWith !== void 0) {
                    await expect(market.getLiquidityValue(test.liquidity)).to.revertedWith(test.revertedWith)
                } else {
                    const res = await market.getLiquidityValue(test.liquidity)
                    expect(res[0]).to.eq(test.outputBase)
                    expect(res[1]).to.eq(test.outputQuote)
                }
            })
        })
    })

    describe("getLiquidityDeleveraged", () => {
        ;[
            {
                title: "normal",
                poolCumDeleveragedBasePerLiquidityX96: BigNumber.from(2).pow(96).mul(2),
                poolCumDeleveragedQuotePerLiquidityX96: BigNumber.from(2).pow(96).mul(20),
                liquidity: 3,
                cumBasePerLiquidityX96: BigNumber.from(2).pow(96),
                cumQuotePerLiquidityX96: BigNumber.from(2).pow(96).mul(10),
                outputBase: 3,
                outputQuote: 30,
            },
            {
                title: "zero liquidity",
                poolCumDeleveragedBasePerLiquidityX96: BigNumber.from(2).pow(96).mul(2),
                poolCumDeleveragedQuotePerLiquidityX96: BigNumber.from(2).pow(96).mul(20),
                liquidity: 0,
                cumBasePerLiquidityX96: BigNumber.from(2).pow(96),
                cumQuotePerLiquidityX96: BigNumber.from(2).pow(96).mul(10),
                outputBase: 0,
                outputQuote: 0,
            },
            {
                title: "zero deleveraged",
                poolCumDeleveragedBasePerLiquidityX96: BigNumber.from(2).pow(96),
                poolCumDeleveragedQuotePerLiquidityX96: BigNumber.from(2).pow(96),
                liquidity: 1,
                cumBasePerLiquidityX96: BigNumber.from(2).pow(96),
                cumQuotePerLiquidityX96: BigNumber.from(2).pow(96),
                outputBase: 0,
                outputQuote: 0,
            },
            {
                title: "minus base",
                poolCumDeleveragedBasePerLiquidityX96: 0,
                poolCumDeleveragedQuotePerLiquidityX96: BigNumber.from(2).pow(96),
                liquidity: 1,
                cumBasePerLiquidityX96: BigNumber.from(2).pow(96),
                cumQuotePerLiquidityX96: BigNumber.from(2).pow(96),
                outputBase: -1,
                outputQuote: 0,
            },
            {
                title: "minus quote",
                poolCumDeleveragedBasePerLiquidityX96: BigNumber.from(2).pow(96),
                poolCumDeleveragedQuotePerLiquidityX96: 0,
                liquidity: 1,
                cumBasePerLiquidityX96: BigNumber.from(2).pow(96),
                cumQuotePerLiquidityX96: BigNumber.from(2).pow(96),
                outputBase: 0,
                outputQuote: -1,
                revertedWith: void 0,
            },
        ].forEach(test => {
            it(test.title, async () => {
                await market.setPoolInfo({
                    base: 0,
                    quote: 0,
                    totalLiquidity: 0,
                    cumBasePerLiquidityX96: test.poolCumDeleveragedBasePerLiquidityX96,
                    cumQuotePerLiquidityX96: test.poolCumDeleveragedQuotePerLiquidityX96,
                    baseBalancePerShareX96: 0,
                })
                if (test.revertedWith !== void 0) {
                    await expect(
                        market.getLiquidityDeleveraged(
                            test.liquidity,
                            test.cumBasePerLiquidityX96,
                            test.cumQuotePerLiquidityX96,
                        ),
                    ).to.revertedWith(test.revertedWith)
                } else {
                    const res = await market.getLiquidityDeleveraged(
                        test.liquidity,
                        test.cumBasePerLiquidityX96,
                        test.cumQuotePerLiquidityX96,
                    )
                    expect(res[0]).to.eq(test.outputBase)
                    expect(res[1]).to.eq(test.outputQuote)
                }
            })
        })
    })

    describe("simple getters", () => {
        it("ok", async () => {
            await market.setPoolInfo({
                base: 0,
                quote: 0,
                totalLiquidity: 0,
                cumBasePerLiquidityX96: 1,
                cumQuotePerLiquidityX96: 2,
                baseBalancePerShareX96: 3,
            })
            const cumPerLiquidityX96 = await market.getCumDeleveragedPerLiquidityX96()
            expect(cumPerLiquidityX96[0]).to.eq(1)
            expect(cumPerLiquidityX96[1]).to.eq(2)
            expect(await market.baseBalancePerShareX96()).to.eq(3)
        })
    })
})
