import { expect } from "chai"
import { waffle } from "hardhat"
import { PerpdexMarket } from "../../typechain"
import { createPerpdexMarketFixture } from "./fixtures"
import { BigNumber, BigNumberish, Wallet } from "ethers"
import { MockContract } from "ethereum-waffle"

describe("PerpdexMarket priceLimit", () => {
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
            liquidationRatio: 5e5,
            emaNormalOrderRatio: 2e5,
            emaLiquidationRatio: 5e5,
            emaSec: 300,
        })
    })

    // TODO: Write if integration test is not enough
    describe("swap twice at different time", () => {
        describe("long", () => {
            it("")
        })

        describe("short", () => {
            it("")
        })
    })

    describe("swap twice at same time", () => {
        describe("long", () => {
            it("")
        })

        describe("short", () => {
            it("")
        })
    })

    describe("ema price limit", () => {
        describe("long", () => {
            it("")
        })

        describe("short", () => {
            it("")
        })
    })

    describe("already in violation of price limits", () => {
        describe("long", () => {
            it("")
        })

        describe("short", () => {
            it("")
        })
    })
})
