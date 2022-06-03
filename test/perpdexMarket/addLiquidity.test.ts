import { expect } from "chai"
import { waffle } from "hardhat"
import { PerpdexMarket } from "../../typechain"
import { createPerpdexMarketFixture } from "./fixtures"
import { BigNumber, BigNumberish, Wallet } from "ethers"
import { MockContract } from "ethereum-waffle"

describe("PerpdexMarket addLiquidity", () => {
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

    describe("caller is not exchange", async () => {
        it("revert", async () => {
            await expect(market.connect(alice).addLiquidity(1, 1)).to.be.revertedWith("PM_OE: caller is not exchange")
        })
    })

    describe("empty pool", async () => {
        ;[
            {
                title: "minimum",
                base: 1001,
                quote: 1001,
                liquidity: 1,
                totalLiquidity: 1001,
            },
            {
                title: "normal",
                base: 10000,
                quote: 10000,
                liquidity: 9000,
                totalLiquidity: 10000,
            },
            {
                title: "normal low price",
                base: 10000,
                quote: 9001,
                liquidity: 8487,
                totalLiquidity: 9487,
            },
            {
                title: "normal high price",
                base: 10000,
                quote: 11000,
                liquidity: 9488,
                totalLiquidity: 10488,
            },
            {
                title: "too low price",
                base: 10000,
                quote: 9000,
                revertedWith: "FL_VILP: too far from index",
            },
            {
                title: "too high price",
                base: 10000,
                quote: 11001,
                revertedWith: "FL_VILP: too far from index",
            },
            {
                title: "same as minimum",
                base: 1000,
                quote: 1000,
                revertedWith: "PL_AL: liquidity zero",
            },
            {
                title: "too small",
                base: 999,
                quote: 999,
                revertedWith: "SafeMath: subtraction overflow",
            },
            {
                title: "overflow",
                base: BigNumber.from(2).pow(128),
                quote: BigNumber.from(2).pow(128),
                revertedWith: "SafeMath: multiplication overflow",
            },
        ].forEach(test => {
            it(test.title, async () => {
                const res = expect(market.connect(exchange).addLiquidity(test.base, test.quote))
                if (test.revertedWith !== void 0) {
                    await res.to.revertedWith(test.revertedWith)
                } else {
                    await res.to.emit(market, "LiquidityAdded").withArgs(test.base, test.quote, test.liquidity)
                    const poolInfo = await market.poolInfo()
                    expect(poolInfo.base).to.eq(test.base)
                    expect(poolInfo.quote).to.eq(test.quote)
                    expect(poolInfo.totalLiquidity).to.eq(test.totalLiquidity)
                }
            })
        })
    })
})
