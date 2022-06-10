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
                isLiquidation: false,
                amount: 490,
            },
            {
                title: "short exact input",
                isBaseToQuote: true,
                isExactInput: true,
                isLiquidation: false,
                amount: 543,
            },
            {
                title: "long exact output",
                isBaseToQuote: false,
                isExactInput: false,
                isLiquidation: false,
                amount: 462,
            },
            {
                title: "short exact output",
                isBaseToQuote: true,
                isExactInput: false,
                isLiquidation: false,
                amount: 509,
            },
        ].forEach(test => {
            it(test.title, async () => {
                const res = await market.maxSwap(test.isBaseToQuote, test.isExactInput, test.isLiquidation)
                expect(res).to.eq(test.amount)
            })
        })
    })

    describe("without fee, with funding. funding not affect swap", () => {
        beforeEach(async () => {
            await priceFeed.mock.getPrice.returns(BigNumber.from(10).pow(18))
            await market.connect(exchange).addLiquidity(10000, 10000)
            await market.connect(owner).setFundingMaxPremiumRatio(5e4)
            await priceFeed.mock.getPrice.returns(2)
        })
        ;[
            {
                title: "long exact input",
                isBaseToQuote: false,
                isExactInput: true,
                isLiquidation: false,
                amount: 488,
            },
            {
                title: "short exact input",
                isBaseToQuote: true,
                isExactInput: true,
                isLiquidation: false,
                amount: 540,
            },
            {
                title: "long exact output",
                isBaseToQuote: false,
                isExactInput: false,
                isLiquidation: false,
                amount: 465,
            },
            {
                title: "short exact output",
                isBaseToQuote: true,
                isExactInput: false,
                isLiquidation: false,
                amount: 512,
            },
            {
                title: "long exact input liquidation",
                isBaseToQuote: false,
                isExactInput: true,
                isLiquidation: true,
                amount: 954,
            },
            {
                title: "short exact input liquidation",
                isBaseToQuote: true,
                isExactInput: true,
                isLiquidation: true,
                amount: 1180,
            },
            {
                title: "long exact output liquidation",
                isBaseToQuote: false,
                isExactInput: false,
                isLiquidation: true,
                amount: 870,
            },
            {
                title: "short exact output liquidation",
                isBaseToQuote: true,
                isExactInput: false,
                isLiquidation: true,
                amount: 1055,
            },
        ].forEach(test => {
            it(test.title, async () => {
                const res = await market.maxSwap(test.isBaseToQuote, test.isExactInput, test.isLiquidation)
                expect(res).to.eq(test.amount)
            })
        })
    })
})
