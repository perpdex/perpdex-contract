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

    describe("getMarkPriceX96 and getShareMarkPriceX96", async () => {
        ;[
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
                    cumDeleveragedBasePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                    baseBalancePerShareX96: test.baseBalancePerShareX96,
                })
                expect(await market.getMarkPriceX96()).to.eq(test.markPriceX96)
                expect(await market.getShareMarkPriceX96()).to.eq(test.shareMarkPriceX96)
            })
        })
    })

    describe("getLiquidityValue", async () => {
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
                    cumDeleveragedBasePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
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

    describe("getLiquidityDeleveraged", async () => {
        ;[
            {
                title: "normal",
                poolCumDeleveragedBasePerLiquidityX96: BigNumber.from(2).pow(96).mul(2),
                poolCumDeleveragedQuotePerLiquidityX96: BigNumber.from(2).pow(96).mul(20),
                liquidity: 3,
                cumDeleveragedBasePerLiquidityX96: BigNumber.from(2).pow(96),
                cumDeleveragedQuotePerLiquidityX96: BigNumber.from(2).pow(96).mul(10),
                outputBase: 3,
                outputQuote: 30,
            },
            {
                title: "zero liquidity",
                poolCumDeleveragedBasePerLiquidityX96: BigNumber.from(2).pow(96).mul(2),
                poolCumDeleveragedQuotePerLiquidityX96: BigNumber.from(2).pow(96).mul(20),
                liquidity: 0,
                cumDeleveragedBasePerLiquidityX96: BigNumber.from(2).pow(96),
                cumDeleveragedQuotePerLiquidityX96: BigNumber.from(2).pow(96).mul(10),
                outputBase: 0,
                outputQuote: 0,
            },
            {
                title: "zero deleveraged",
                poolCumDeleveragedBasePerLiquidityX96: BigNumber.from(2).pow(96),
                poolCumDeleveragedQuotePerLiquidityX96: BigNumber.from(2).pow(96),
                liquidity: 1,
                cumDeleveragedBasePerLiquidityX96: BigNumber.from(2).pow(96),
                cumDeleveragedQuotePerLiquidityX96: BigNumber.from(2).pow(96),
                outputBase: 0,
                outputQuote: 0,
            },
            {
                title: "minus base",
                poolCumDeleveragedBasePerLiquidityX96: 0,
                poolCumDeleveragedQuotePerLiquidityX96: BigNumber.from(2).pow(96),
                liquidity: 1,
                cumDeleveragedBasePerLiquidityX96: BigNumber.from(2).pow(96),
                cumDeleveragedQuotePerLiquidityX96: BigNumber.from(2).pow(96),
                revertedWith: "SafeMath: subtraction overflow",
            },
            {
                title: "minus quote",
                poolCumDeleveragedBasePerLiquidityX96: BigNumber.from(2).pow(96),
                poolCumDeleveragedQuotePerLiquidityX96: 0,
                liquidity: 1,
                cumDeleveragedBasePerLiquidityX96: BigNumber.from(2).pow(96),
                cumDeleveragedQuotePerLiquidityX96: BigNumber.from(2).pow(96),
                revertedWith: "SafeMath: subtraction overflow",
            },
        ].forEach(test => {
            it(test.title, async () => {
                await market.setPoolInfo({
                    base: 0,
                    quote: 0,
                    totalLiquidity: 0,
                    cumDeleveragedBasePerLiquidityX96: test.poolCumDeleveragedBasePerLiquidityX96,
                    cumDeleveragedQuotePerLiquidityX96: test.poolCumDeleveragedQuotePerLiquidityX96,
                    baseBalancePerShareX96: 0,
                })
                if (test.revertedWith !== void 0) {
                    await expect(
                        market.getLiquidityDeleveraged(
                            test.liquidity,
                            test.cumDeleveragedBasePerLiquidityX96,
                            test.cumDeleveragedQuotePerLiquidityX96,
                        ),
                    ).to.revertedWith(test.revertedWith)
                } else {
                    const res = await market.getLiquidityDeleveraged(
                        test.liquidity,
                        test.cumDeleveragedBasePerLiquidityX96,
                        test.cumDeleveragedQuotePerLiquidityX96,
                    )
                    expect(res[0]).to.eq(test.outputBase)
                    expect(res[1]).to.eq(test.outputQuote)
                }
            })
        })
    })

    describe("simple getters", async () => {
        it("ok", async () => {
            await market.setPoolInfo({
                base: 0,
                quote: 0,
                totalLiquidity: 0,
                cumDeleveragedBasePerLiquidityX96: 1,
                cumDeleveragedQuotePerLiquidityX96: 2,
                baseBalancePerShareX96: 3,
            })
            const cumDeleveragedPerLiquidityX96 = await market.getCumDeleveragedPerLiquidityX96()
            expect(cumDeleveragedPerLiquidityX96[0]).to.eq(1)
            expect(cumDeleveragedPerLiquidityX96[1]).to.eq(2)
            expect(await market.baseBalancePerShareX96()).to.eq(3)
        })
    })
})
