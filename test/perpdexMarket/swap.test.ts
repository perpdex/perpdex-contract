import { expect } from "chai"
import { waffle } from "hardhat"
import { PerpdexMarket } from "../../typechain"
import { createPerpdexMarketFixture } from "./fixtures"
import { BigNumber, BigNumberish, Wallet } from "ethers"

describe("PerpdexMarket swap", () => {
    let loadFixture = waffle.createFixtureLoader(waffle.provider.getWallets())
    let fixture

    let market: PerpdexMarket
    let owner: Wallet
    let alice: Wallet
    let exchange: Wallet

    beforeEach(async () => {
        fixture = await loadFixture(createPerpdexMarketFixture())
        market = fixture.perpdexMarket
        owner = fixture.owner
        alice = fixture.alice
        exchange = fixture.exchange
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
            await market.connect(owner).setPoolFeeRatio(0)
            await market.connect(owner).setFundingMaxPremiumRatio(0)
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
        ].forEach(test => {
            it(test.title, async () => {
                await expect(market.connect(exchange).swap(test.isBaseToQuote, test.isExactInput, test.amount))
                    .to.emit(market, "Swapped")
                    .withArgs(test.isBaseToQuote, test.isExactInput, test.amount, test.oppositeAmount)
                const poolInfo = await market.poolInfo()
                expect(poolInfo.base).to.eq(test.base)
                expect(poolInfo.quote).to.eq(test.quote)
            })
        })
    })

    describe("with fee, without funding", async () => {
        beforeEach(async () => {
            await market.connect(owner).setPoolFeeRatio(1e4)
            await market.connect(owner).setFundingMaxPremiumRatio(0)
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
        })
    })
})
