import { expect } from "chai"
import { waffle } from "hardhat"
import { TestPoolLibrary } from "../../typechain"
import { createPoolLibraryFixture } from "./fixtures"
import { BigNumber, BigNumberish, Wallet } from "ethers"
import { MockContract } from "ethereum-waffle"

describe("PoolLibrary", () => {
    let loadFixture = waffle.createFixtureLoader(waffle.provider.getWallets())
    let fixture

    let poolLibrary: TestPoolLibrary

    beforeEach(async () => {
        fixture = await loadFixture(createPoolLibraryFixture())
        poolLibrary = fixture.poolLibrary
    })

    describe("applyFunding", () => {
        ;[
            {
                title: "zero",
                base: 10000,
                quote: 10000,
                totalLiquidity: 10000,
                cumDeleveragedBasePerLiquidityX96: 1,
                cumDeleveragedQuotePerLiquidityX96: 1,
                baseBalancePerShareX96: BigNumber.from(10).pow(18),
                fundingRateX96: 0,
                afterBase: 10000,
                afterQuote: 10000,
                afterCumDeleveragedBasePerLiquidityX96: 1,
                afterCumDeleveragedQuotePerLiquidityX96: 1,
                afterBaseBalancePerShareX96: BigNumber.from(10).pow(18),
            },
            {
                title: "positive",
                base: 10000,
                quote: 10000,
                totalLiquidity: 10000,
                cumDeleveragedBasePerLiquidityX96: 1,
                cumDeleveragedQuotePerLiquidityX96: 1,
                baseBalancePerShareX96: BigNumber.from(10).pow(18),
                fundingRateX96: BigNumber.from(2).pow(96).div(4),
                afterBase: 10000,
                afterQuote: 7500,
                afterCumDeleveragedBasePerLiquidityX96: 1,
                afterCumDeleveragedQuotePerLiquidityX96: BigNumber.from(2).pow(96).div(4).add(1),
                afterBaseBalancePerShareX96: BigNumber.from(10).pow(18).mul(3).div(4),
            },
            {
                title: "negative",
                base: 10000,
                quote: 10000,
                totalLiquidity: 10000,
                cumDeleveragedBasePerLiquidityX96: 1,
                cumDeleveragedQuotePerLiquidityX96: 1,
                baseBalancePerShareX96: BigNumber.from(10).pow(18),
                fundingRateX96: BigNumber.from(2).pow(96).div(-4),
                afterBase: 8000,
                afterQuote: 10000,
                afterCumDeleveragedBasePerLiquidityX96: BigNumber.from(2).pow(96).div(5).add(1),
                afterCumDeleveragedQuotePerLiquidityX96: 1,
                afterBaseBalancePerShareX96: BigNumber.from(10).pow(18).mul(5).div(4),
            },
        ].forEach(test => {
            it(test.title, async () => {
                await poolLibrary.setPoolInfo({
                    base: test.base,
                    quote: test.quote,
                    totalLiquidity: test.totalLiquidity,
                    cumDeleveragedBasePerLiquidityX96: test.cumDeleveragedBasePerLiquidityX96,
                    cumDeleveragedQuotePerLiquidityX96: test.cumDeleveragedQuotePerLiquidityX96,
                    baseBalancePerShareX96: test.baseBalancePerShareX96,
                })

                await poolLibrary.applyFunding(test.fundingRateX96)

                const res = await poolLibrary.poolInfo()
                expect(res.base).to.eq(test.afterBase)
                expect(res.quote).to.eq(test.afterQuote)
                expect(res.totalLiquidity).to.eq(test.totalLiquidity)
                expect(res.cumDeleveragedBasePerLiquidityX96).to.eq(test.afterCumDeleveragedBasePerLiquidityX96)
                expect(res.cumDeleveragedQuotePerLiquidityX96).to.eq(test.afterCumDeleveragedQuotePerLiquidityX96)
                expect(res.baseBalancePerShareX96).to.eq(test.afterBaseBalancePerShareX96)
            })
        })
    })
})
