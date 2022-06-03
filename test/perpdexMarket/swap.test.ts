import { expect } from "chai"
import { waffle } from "hardhat"
import { PerpdexMarket } from "../../typechain"
import { createPerpdexMarketFixture } from "./fixtures"
import { BigNumber, BigNumberish, Wallet } from "ethers"
import { MockContract } from "ethereum-waffle"

describe("PerpdexMarket swap", () => {
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
    })

    describe("caller is not exchange", async () => {
        it("revert", async () => {
            await expect(market.connect(alice).swap(false, true, 1)).to.be.revertedWith("PM_OE: caller is not exchange")
        })
    })

    describe("empty pool", async () => {
        it("revert", async () => {
            await expect(market.connect(exchange).swap(false, true, 1)).to.be.reverted
        })
    })

    describe("without fee, without funding", async () => {
        beforeEach(async () => {
            await market.connect(exchange).addLiquidity(10000, 10000)
        })
        ;[
            {
                title: "long exact input",
                isBaseToQuote: false,
                isExactInput: true,
                amount: 10000,
                oppositeAmount: 5000,
                base: 5000,
                quote: 20000,
            },
            {
                title: "short exact input",
                isBaseToQuote: true,
                isExactInput: true,
                amount: 10000,
                oppositeAmount: 5000,
                base: 20000,
                quote: 5000,
            },
            {
                title: "long exact output",
                isBaseToQuote: false,
                isExactInput: false,
                amount: 5000,
                oppositeAmount: 10000,
                base: 5000,
                quote: 20000,
            },
            {
                title: "short exact input",
                isBaseToQuote: true,
                isExactInput: false,
                amount: 5000,
                oppositeAmount: 10000,
                base: 20000,
                quote: 5000,
            },
            {
                title: "long exact input zero",
                isBaseToQuote: false,
                isExactInput: true,
                amount: 0,
                revertedWith: "PL_SD: output is zero",
            },
            {
                title: "short exact input zero",
                isBaseToQuote: true,
                isExactInput: true,
                amount: 0,
                revertedWith: "PL_SD: output is zero",
            },
            {
                title: "long exact output zero",
                isBaseToQuote: false,
                isExactInput: false,
                amount: 0,
                revertedWith: "PL_SD: output is zero",
            },
            {
                title: "short exact input zero",
                isBaseToQuote: true,
                isExactInput: false,
                amount: 0,
                revertedWith: "PL_SD: output is zero",
            },
            {
                title: "long exact input rounded to benefit pool",
                isBaseToQuote: false,
                isExactInput: true,
                amount: 10001,
                oppositeAmount: 5000,
                base: 5000,
                quote: 20001,
            },
            {
                title: "short exact input rounded to benefit pool",
                isBaseToQuote: true,
                isExactInput: true,
                amount: 10001,
                oppositeAmount: 5000,
                base: 20001,
                quote: 5000,
            },
            {
                title: "long exact output rounded to benefit pool",
                isBaseToQuote: false,
                isExactInput: false,
                amount: 5001,
                oppositeAmount: 10005,
                base: 4999,
                quote: 20005,
            },
            {
                title: "short exact output rounded to benefit pool",
                isBaseToQuote: true,
                isExactInput: false,
                amount: 5001,
                oppositeAmount: 10005,
                base: 20005,
                quote: 4999,
            },
            {
                title: "long revert when output is too small",
                isBaseToQuote: false,
                isExactInput: true,
                amount: 1,
                revertedWith: "PL_SD: output is zero",
            },
            {
                title: "short revert when output is too small",
                isBaseToQuote: true,
                isExactInput: true,
                amount: 1,
                revertedWith: "PL_SD: output is zero",
            },
            {
                title: "long revert when insufficient base liquidity",
                isBaseToQuote: false,
                isExactInput: false,
                amount: 10000,
                revertedWith: "",
            },
            {
                title: "short revert when insufficient quote liquidity",
                isBaseToQuote: true,
                isExactInput: false,
                amount: 10000,
                revertedWith: "",
            },
            {
                title: "long revert when insufficient base liquidity over",
                isBaseToQuote: false,
                isExactInput: false,
                amount: 10001,
                revertedWith: "SafeMath: subtraction overflow",
            },
            {
                title: "short revert when insufficient quote liquidity over",
                isBaseToQuote: true,
                isExactInput: false,
                amount: 10001,
                revertedWith: "SafeMath: subtraction overflow",
            },
            {
                title: "long revert when too large amount",
                isBaseToQuote: false,
                isExactInput: true,
                amount: BigNumber.from(2).pow(256).sub(1),
                revertedWith: "SafeMath: addition overflow",
            },
            {
                title: "short revert when too large amount",
                isBaseToQuote: true,
                isExactInput: true,
                amount: BigNumber.from(2).pow(256).sub(1),
                revertedWith: "SafeMath: addition overflow",
            },
            {
                title: "liquidity remain when too large long not overflow",
                isBaseToQuote: false,
                isExactInput: true,
                amount: BigNumber.from(2).pow(128),
                oppositeAmount: 9999,
                base: 1,
                quote: BigNumber.from(2).pow(128).add(10000),
            },
            {
                title: "liquidity remain when too large short not overflow",
                isBaseToQuote: true,
                isExactInput: true,
                amount: BigNumber.from(2).pow(128),
                oppositeAmount: 9999,
                base: BigNumber.from(2).pow(128).add(10000),
                quote: 1,
            },
        ].forEach(test => {
            it(test.title, async () => {
                const res = expect(market.connect(exchange).swap(test.isBaseToQuote, test.isExactInput, test.amount))
                if (test.revertedWith !== void 0) {
                    await res.to.revertedWith(test.revertedWith)
                } else {
                    await res.to
                        .emit(market, "Swapped")
                        .withArgs(test.isBaseToQuote, test.isExactInput, test.amount, test.oppositeAmount)
                    const poolInfo = await market.poolInfo()
                    expect(poolInfo.base).to.eq(test.base)
                    expect(poolInfo.quote).to.eq(test.quote)
                }
            })

            it(test.title + " dry", async () => {
                if (test.revertedWith !== void 0) {
                    await expect(market.swapDry(test.isBaseToQuote, test.isExactInput, test.amount)).to.revertedWith(
                        test.revertedWith,
                    )
                } else {
                    const res = await market.swapDry(test.isBaseToQuote, test.isExactInput, test.amount)
                    expect(res).to.eq(test.oppositeAmount)
                }
            })
        })
    })

    describe("with fee, without funding", async () => {
        beforeEach(async () => {
            await market.connect(owner).setPoolFeeRatio(1e4)
            await market.connect(exchange).addLiquidity(10000, 10000)
        })
        ;[
            {
                title: "long exact input",
                isBaseToQuote: false,
                isExactInput: true,
                amount: 10100,
                oppositeAmount: 5000,
                base: 5000,
                quote: 20100,
            },
            {
                title: "short exact input",
                isBaseToQuote: true,
                isExactInput: true,
                amount: 10100,
                oppositeAmount: 5000,
                base: 20100,
                quote: 5000,
            },
            {
                title: "long exact output",
                isBaseToQuote: false,
                isExactInput: false,
                amount: 5000,
                oppositeAmount: 10100,
                base: 5000,
                quote: 20100,
            },
            {
                title: "short exact input",
                isBaseToQuote: true,
                isExactInput: false,
                amount: 5000,
                oppositeAmount: 10100,
                base: 20100,
                quote: 5000,
            },
        ].forEach(test => {
            it(test.title, async () => {
                await expect(market.connect(exchange).swap(test.isBaseToQuote, test.isExactInput, test.amount))
                    .to.emit(market, "Swapped")
                    .withArgs(test.isBaseToQuote, test.isExactInput, test.amount, test.oppositeAmount)
                const poolInfo = await market.poolInfo()
                expect(poolInfo.base).to.eq(test.base)
                expect(poolInfo.quote).to.eq(test.quote)
            })

            it(test.title + " dry", async () => {
                const res = await market.swapDry(test.isBaseToQuote, test.isExactInput, test.amount)
                expect(res).to.eq(test.oppositeAmount)
            })
        })
    })

    describe("without fee, with funding", async () => {
        beforeEach(async () => {
            await priceFeed.mock.getPrice.returns(BigNumber.from(10).pow(18))
            await market.connect(exchange).addLiquidity(10000, 10000)
            await market.connect(owner).setFundingMaxPremiumRatio(5e4)
            await priceFeed.mock.getPrice.returns(2)
        })
        ;[
            {
                title: "long exact input. funding not affect swap",
                isBaseToQuote: false,
                isExactInput: true,
                amount: 10000,
                oppositeAmount: 5000,
                base: 5000,
                quote: 20000,
            },
            {
                title: "short exact input. funding not affect swap",
                isBaseToQuote: true,
                isExactInput: true,
                amount: 10000,
                oppositeAmount: 5000,
                base: 20000,
                quote: 5000,
            },
            {
                title: "long exact output. funding not affect swap",
                isBaseToQuote: false,
                isExactInput: false,
                amount: 5000,
                oppositeAmount: 10000,
                base: 5000,
                quote: 20000,
            },
            {
                title: "short exact input. funding not affect swap",
                isBaseToQuote: true,
                isExactInput: false,
                amount: 5000,
                oppositeAmount: 10000,
                base: 20000,
                quote: 5000,
            },
        ].forEach(test => {
            it(test.title, async () => {
                await expect(market.connect(exchange).swap(test.isBaseToQuote, test.isExactInput, test.amount))
                    .to.emit(market, "Swapped")
                    .withArgs(test.isBaseToQuote, test.isExactInput, test.amount, test.oppositeAmount)
                    .to.emit(market, "FundingPaid")
                const poolInfo = await market.poolInfo()
                expect(poolInfo.quote).to.eq(test.quote)
            })

            it(test.title + " dry", async () => {
                const res = await market.swapDry(test.isBaseToQuote, test.isExactInput, test.amount)
                expect(res).to.eq(test.oppositeAmount)
            })
        })
    })
})
