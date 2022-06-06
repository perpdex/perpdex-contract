import { expect } from "chai"
import { waffle } from "hardhat"
import { PerpdexMarket } from "../../typechain"
import { createPerpdexMarketFixture } from "./fixtures"
import { BigNumber, BigNumberish, Wallet } from "ethers"
import { MockContract } from "ethereum-waffle"

describe("PerpdexMarket removeLiquidity", () => {
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

    describe("caller is not exchange", () => {
        it("revert", async () => {
            await expect(market.connect(alice).removeLiquidity(1)).to.be.revertedWith("PM_OE: caller is not exchange")
        })
    })

    describe("empty pool", () => {
        ;[
            {
                title: "zero",
                liquidity: 0,
                revertedWith: "",
            },
            {
                title: "small",
                liquidity: 1,
                revertedWith: "",
            },
            {
                title: "too large",
                liquidity: BigNumber.from(2).pow(256).sub(1),
                revertedWith: "",
            },
        ].forEach(test => {
            it(test.title, async () => {
                const res = expect(market.connect(exchange).removeLiquidity(test.liquidity))
                await res.to.revertedWith(test.revertedWith)
            })
        })
    })

    describe("non empty pool", () => {
        beforeEach(async () => {
            await market.connect(exchange).addLiquidity(10000, 10000)
        })
        ;[
            {
                title: "normal",
                liquidity: 1,
                outputBase: 1,
                outputQuote: 1,
            },
            {
                title: "zero",
                liquidity: 0,
                revertedWith: "PL_RL: output is zero",
            },
            {
                title: "min liquidity",
                liquidity: 9000,
                outputBase: 9000,
                outputQuote: 9000,
            },
            {
                title: "less than min liquidity",
                liquidity: 9001,
                revertedWith: "PL_RL: min liquidity",
            },
            {
                title: "all",
                liquidity: 10000,
                revertedWith: "PL_RL: min liquidity",
            },
            {
                title: "too large",
                liquidity: 10001,
                revertedWith: "SafeMath: subtraction overflow",
            },
            {
                title: "overflow",
                liquidity: BigNumber.from(2).pow(256).sub(1),
                revertedWith: "SafeMath: subtraction overflow",
            },
        ].forEach(test => {
            it(test.title, async () => {
                const res = expect(market.connect(exchange).removeLiquidity(test.liquidity))
                if (test.revertedWith !== void 0) {
                    await res.to.revertedWith(test.revertedWith)
                } else {
                    await res.to
                        .emit(market, "LiquidityRemoved")
                        .withArgs(test.outputBase, test.outputQuote, test.liquidity)
                    const poolInfo = await market.poolInfo()
                    expect(poolInfo.base).to.eq(10000 - test.outputBase)
                    expect(poolInfo.quote).to.eq(10000 - test.outputQuote)
                    expect(poolInfo.totalLiquidity).to.eq(BigNumber.from(10000).sub(test.liquidity))
                }
            })
        })
    })

    describe("rounding (benefit to others)", () => {
        ;[
            {
                title: "quote rounded",
                initialBase: 10000,
                initialQuote: 10001,
                initialLiquidity: 10000,
                liquidity: 1,
                outputBase: 1,
                outputQuote: 1,
            },
            {
                title: "base rounded",
                initialBase: 10001,
                initialQuote: 10000,
                initialLiquidity: 10000,
                liquidity: 1,
                outputBase: 1,
                outputQuote: 1,
            },
        ].forEach(test => {
            it(test.title, async () => {
                const resInitial = expect(market.connect(exchange).addLiquidity(test.initialBase, test.initialQuote))
                await resInitial.to
                    .emit(market, "LiquidityAdded")
                    .withArgs(test.initialBase, test.initialQuote, test.initialLiquidity - 1000)

                const res = expect(market.connect(exchange).removeLiquidity(test.liquidity))
                await res.to
                    .emit(market, "LiquidityRemoved")
                    .withArgs(test.outputBase, test.outputQuote, test.liquidity)
                const poolInfo = await market.poolInfo()
                expect(poolInfo.base).to.eq(test.initialBase - test.outputBase)
                expect(poolInfo.quote).to.eq(test.initialQuote - test.outputQuote)
                expect(poolInfo.totalLiquidity).to.eq(BigNumber.from(test.initialLiquidity).sub(test.liquidity))
            })
        })
    })
})
