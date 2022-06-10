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
        await market.connect(owner).setPriceLimitConfig({
            normalOrderRatio: 5e5,
            liquidationRatio: 5e5,
            emaNormalOrderRatio: 5e5,
            emaLiquidationRatio: 5e5,
            emaSec: 0,
        })
    })

    describe("caller is not exchange", () => {
        it("revert", async () => {
            await expect(market.connect(alice).swap(false, true, 1, false)).to.be.revertedWith(
                "PM_OE: caller is not exchange",
            )
        })
    })

    describe("empty pool", () => {
        it("revert", async () => {
            await expect(market.connect(exchange).swap(false, true, 1, false)).to.be.reverted
        })

        it("revert preview", async () => {
            await expect(market.connect(exchange).previewSwap(false, true, 1, false)).to.be.reverted
        })
    })

    describe("with fee, without funding", () => {
        beforeEach(async () => {
            await market.connect(owner).setPoolFeeRatio(1e4)
            await market.connect(exchange).addLiquidity(10000, 10000)
        })
        ;[
            {
                title: "long exact input",
                isBaseToQuote: false,
                isExactInput: true,
                amount: 1000,
                oppositeAmount: 900,
                base: 9100,
                quote: 11000,
            },
            {
                title: "short exact input",
                isBaseToQuote: true,
                isExactInput: true,
                amount: 1000,
                oppositeAmount: 900,
                base: 11000,
                quote: 9100,
            },
            {
                title: "long exact output",
                isBaseToQuote: false,
                isExactInput: false,
                amount: 900,
                oppositeAmount: 1000,
                base: 9100,
                quote: 11000,
            },
            {
                title: "short exact output",
                isBaseToQuote: true,
                isExactInput: false,
                amount: 900,
                oppositeAmount: 1000,
                base: 11000,
                quote: 9100,
            },
        ].forEach(test => {
            it(test.title, async () => {
                const res = expect(
                    market.connect(exchange).swap(test.isBaseToQuote, test.isExactInput, test.amount, false),
                )
                await res.to
                    .emit(market, "Swapped")
                    .withArgs(test.isBaseToQuote, test.isExactInput, test.amount, test.oppositeAmount)
                const poolInfo = await market.poolInfo()
                expect(poolInfo.base).to.eq(test.base)
                expect(poolInfo.quote).to.eq(test.quote)
            })

            it(test.title + " dry", async () => {
                const res = await market.previewSwap(test.isBaseToQuote, test.isExactInput, test.amount, false)
                expect(res).to.eq(test.oppositeAmount)
            })
        })
    })

    describe("without fee, with funding", () => {
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
                amount: 100,
                oppositeAmount: 99,
                base: 9901,
                quote: 10100,
            },
            {
                title: "short exact input. funding not affect swap",
                isBaseToQuote: true,
                isExactInput: true,
                amount: 100,
                oppositeAmount: 99,
                base: 10100,
                quote: 9901,
            },
            {
                title: "long exact output. funding not affect swap",
                isBaseToQuote: false,
                isExactInput: false,
                amount: 99,
                oppositeAmount: 100,
                base: 9901,
                quote: 10100,
            },
            {
                title: "short exact input. funding not affect swap",
                isBaseToQuote: true,
                isExactInput: false,
                amount: 99,
                oppositeAmount: 100,
                base: 10100,
                quote: 9901,
            },
        ].forEach(test => {
            it(test.title, async () => {
                await expect(market.connect(exchange).swap(test.isBaseToQuote, test.isExactInput, test.amount, false))
                    .to.emit(market, "Swapped")
                    .withArgs(test.isBaseToQuote, test.isExactInput, test.amount, test.oppositeAmount)
                    .to.emit(market, "FundingPaid")
                const poolInfo = await market.poolInfo()
                expect(poolInfo.base).to.eq(test.base)
                expect(poolInfo.quote).to.eq(test.quote)
            })

            it(test.title + " dry", async () => {
                const res = await market.previewSwap(test.isBaseToQuote, test.isExactInput, test.amount, false)
                expect(res).to.eq(test.oppositeAmount)
            })
        })
    })
})
