import { expect } from "chai"
import { waffle } from "hardhat"
import { PerpdexMarket } from "../../typechain"
import { createPerpdexMarketFixture } from "./fixtures"
import { BigNumber, BigNumberish, Wallet } from "ethers"
import { MockContract } from "ethereum-waffle"

describe("PerpdexMarket maxSwap", () => {
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
            normalOrderRatio: 1e5,
            liquidationRatio: 2e5,
            emaNormalOrderRatio: 5e5,
            emaLiquidationRatio: 5e5,
            emaSec: 0,
        })
    })

    describe("empty pool", () => {
        it("return 0", async () => {
            expect(await market.connect(exchange).maxSwap(false, true, false)).to.eq(0)
        })
    })

    // describe("with fee, without funding", () => {
    //     beforeEach(async () => {
    //         await market.connect(owner).setPoolFeeRatio(1e4)
    //         await market.connect(exchange).addLiquidity(10000, 10000)
    //     })
    //     ;[
    //         {
    //             title: "long exact input",
    //             isBaseToQuote: false,
    //             isExactInput: true,
    //             isLiquidation: false,
    //             amount: 1,
    //         },
    //         {
    //             title: "short exact input",
    //             isBaseToQuote: true,
    //             isExactInput: true,
    //             isLiquidation: false,
    //             amount: 1,
    //         },
    //         {
    //             title: "long exact output",
    //             isBaseToQuote: false,
    //             isExactInput: false,
    //             isLiquidation: false,
    //             amount: 1,
    //         },
    //         {
    //             title: "short exact output",
    //             isBaseToQuote: true,
    //             isExactInput: false,
    //             isLiquidation: false,
    //             amount: 1,
    //         },
    //     ].forEach(test => {
    //         it(test.title, async () => {
    //             const res = await market.maxSwap(test.isBaseToQuote, test.isExactInput, test.isLiquidation)
    //             expect(res).to.eq(test.amount)
    //         })
    //     })
    // })

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
                isLiquidation: false,
                amount: 488,
            },
            {
                title: "short exact input. funding not affect swap",
                isBaseToQuote: true,
                isExactInput: true,
                isLiquidation: false,
                amount: 540,
            },
            {
                title: "long exact output. funding not affect swap",
                isBaseToQuote: false,
                isExactInput: false,
                isLiquidation: false,
                amount: 465,
            },
            {
                title: "short exact input. funding not affect swap",
                isBaseToQuote: true,
                isExactInput: false,
                isLiquidation: false,
                amount: 513,
            },
        ].forEach(test => {
            it(test.title, async () => {
                const res = await market.maxSwap(test.isBaseToQuote, test.isExactInput, test.isLiquidation)
                expect(res).to.eq(test.amount)
            })
        })
    })

    describe("consistent with previewSwap", () => {
        beforeEach(async () => {
            await market.connect(exchange).addLiquidity(10000, 10000)
        })
        ;[
            {
                title: "long exact input",
                isBaseToQuote: false,
                isExactInput: true,
                isLiquidation: false,
            },
            {
                title: "short exact input",
                isBaseToQuote: true,
                isExactInput: true,
                isLiquidation: false,
            },
            {
                title: "long exact output",
                isBaseToQuote: false,
                isExactInput: false,
                isLiquidation: false,
            },
            {
                title: "short exact input",
                isBaseToQuote: true,
                isExactInput: false,
                isLiquidation: false,
            },
            {
                title: "long exact input liquidation",
                isBaseToQuote: false,
                isExactInput: true,
                isLiquidation: true,
            },
            {
                title: "short exact input liquidation",
                isBaseToQuote: true,
                isExactInput: true,
                isLiquidation: true,
            },
            {
                title: "long exact output liquidation",
                isBaseToQuote: false,
                isExactInput: false,
                isLiquidation: true,
            },
            {
                title: "short exact input liquidation",
                isBaseToQuote: true,
                isExactInput: false,
                isLiquidation: true,
            },
        ].forEach(test => {
            it(test.title, async () => {
                const amount = await market.maxSwap(test.isBaseToQuote, test.isExactInput, test.isLiquidation)
                const res = market.previewSwap(test.isBaseToQuote, test.isExactInput, amount, test.isLiquidation)
                await expect(res).not.to.reverted
                const res2 = market.previewSwap(
                    test.isBaseToQuote,
                    test.isExactInput,
                    amount.add(1),
                    test.isLiquidation,
                )
                await expect(res2).to.reverted
            })
        })
    })
})
