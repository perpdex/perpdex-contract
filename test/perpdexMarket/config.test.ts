import { expect } from "chai"
import { waffle } from "hardhat"
import { PerpdexMarket } from "../../typechain"
import { createPerpdexMarketFixture } from "./fixtures"
import { Wallet } from "ethers"

describe("PerpdexMarket config", () => {
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

    describe("initial values", () => {
        it("ok", async () => {
            const priceLimitConfig = await market.priceLimitConfig()
            expect(priceLimitConfig.normalOrderRatio).to.eq(5e4)
            expect(priceLimitConfig.liquidationRatio).to.eq(10e4)
            expect(priceLimitConfig.emaNormalOrderRatio).to.eq(20e4)
            expect(priceLimitConfig.emaLiquidationRatio).to.eq(25e4)
            expect(priceLimitConfig.emaSec).to.eq(300)

            expect(await market.poolFeeRatio()).to.eq(3e3)
            expect(await market.fundingMaxPremiumRatio()).to.eq(1e4)
            expect(await market.fundingMaxElapsedSec()).to.eq(24 * 60 * 60)
            expect(await market.fundingRolloverSec()).to.eq(24 * 60 * 60)
        })
    })

    describe("setPriceLimitConfig", () => {
        it("ok", async () => {
            await expect(
                market.connect(owner).setPriceLimitConfig({
                    normalOrderRatio: 0,
                    liquidationRatio: 0,
                    emaNormalOrderRatio: 0,
                    emaLiquidationRatio: 0,
                    emaSec: 0,
                }),
            )
                .to.emit(market, "PriceLimitConfigChanged")
                .withArgs(0, 0, 0, 0, 0)
            let priceLimitConfig = await market.priceLimitConfig()
            expect(priceLimitConfig.normalOrderRatio).to.eq(0)
            expect(priceLimitConfig.liquidationRatio).to.eq(0)

            await expect(
                market.connect(owner).setPriceLimitConfig({
                    normalOrderRatio: 1,
                    liquidationRatio: 5e5,
                    emaNormalOrderRatio: 2,
                    emaLiquidationRatio: 1e6 - 1,
                    emaSec: 1,
                }),
            )
                .to.emit(market, "PriceLimitConfigChanged")
                .withArgs(1, 5e5, 2, 1e6 - 1, 1)
            priceLimitConfig = await market.priceLimitConfig()
            expect(priceLimitConfig.normalOrderRatio).to.eq(1)
            expect(priceLimitConfig.liquidationRatio).to.eq(5e5)
            expect(priceLimitConfig.emaNormalOrderRatio).to.eq(2)
            expect(priceLimitConfig.emaLiquidationRatio).to.eq(1e6 - 1)
            expect(priceLimitConfig.emaSec).to.eq(1)
        })

        it("revert when not owner", async () => {
            await expect(
                market.connect(alice).setPriceLimitConfig({
                    normalOrderRatio: 0,
                    liquidationRatio: 0,
                    emaNormalOrderRatio: 0,
                    emaLiquidationRatio: 0,
                    emaSec: 0,
                }),
            ).to.be.revertedWith("Ownable: caller is not the owner")
        })

        it("revert when too large", async () => {
            await expect(
                market.connect(owner).setPriceLimitConfig({
                    normalOrderRatio: 0,
                    liquidationRatio: 5e5 + 1,
                    emaNormalOrderRatio: 0,
                    emaLiquidationRatio: 0,
                    emaSec: 0,
                }),
            ).to.be.revertedWith("PE_SPLC: too large liquidation")
        })

        it("revert when normal order > liquidation", async () => {
            await expect(
                market.connect(owner).setPriceLimitConfig({
                    normalOrderRatio: 2,
                    liquidationRatio: 1,
                    emaNormalOrderRatio: 0,
                    emaLiquidationRatio: 0,
                    emaSec: 0,
                }),
            ).to.be.revertedWith("PE_SPLC: invalid")
        })

        it("revert when ema too large", async () => {
            await expect(
                market.connect(owner).setPriceLimitConfig({
                    normalOrderRatio: 0,
                    liquidationRatio: 0,
                    emaNormalOrderRatio: 0,
                    emaLiquidationRatio: 1e6,
                    emaSec: 0,
                }),
            ).to.be.revertedWith("PE_SPLC: ema too large liq")
        })

        it("revert when ema normal order > liquidation", async () => {
            await expect(
                market.connect(owner).setPriceLimitConfig({
                    normalOrderRatio: 0,
                    liquidationRatio: 0,
                    emaNormalOrderRatio: 2,
                    emaLiquidationRatio: 1,
                    emaSec: 0,
                }),
            ).to.be.revertedWith("PE_SPLC: ema invalid")
        })
    })

    describe("setPoolFeeRatio", () => {
        it("ok", async () => {
            await expect(market.connect(owner).setPoolFeeRatio(0)).to.emit(market, "PoolFeeRatioChanged").withArgs(0)
            expect(await market.poolFeeRatio()).to.eq(0)
            await expect(market.connect(owner).setPoolFeeRatio(5e4))
                .to.emit(market, "PoolFeeRatioChanged")
                .withArgs(5e4)
            expect(await market.poolFeeRatio()).to.eq(5e4)
        })

        it("revert when not owner", async () => {
            await expect(market.connect(alice).setPoolFeeRatio(1)).to.be.revertedWith(
                "Ownable: caller is not the owner",
            )
        })

        it("revert when too large", async () => {
            await expect(market.connect(owner).setPoolFeeRatio(5e4 + 1)).to.be.revertedWith("PM_SPFR: too large")
        })
    })

    describe("setFundingMaxPremiumRatio", () => {
        it("ok", async () => {
            await expect(market.connect(owner).setFundingMaxPremiumRatio(0))
                .to.emit(market, "FundingMaxPremiumRatioChanged")
                .withArgs(0)
            expect(await market.fundingMaxPremiumRatio()).to.eq(0)
            await expect(market.connect(owner).setFundingMaxPremiumRatio(1e5))
                .to.emit(market, "FundingMaxPremiumRatioChanged")
                .withArgs(1e5)
            expect(await market.fundingMaxPremiumRatio()).to.eq(1e5)
        })

        it("revert when not owner", async () => {
            await expect(market.connect(alice).setFundingMaxPremiumRatio(1)).to.be.revertedWith(
                "Ownable: caller is not the owner",
            )
        })

        it("revert when too large", async () => {
            await expect(market.connect(owner).setFundingMaxPremiumRatio(1e5 + 1)).to.be.revertedWith(
                "PM_SFMPR: too large",
            )
        })
    })

    describe("setFundingMaxElapsedSec", () => {
        it("ok", async () => {
            await expect(market.connect(owner).setFundingMaxElapsedSec(0))
                .to.emit(market, "FundingMaxElapsedSecChanged")
                .withArgs(0)
            expect(await market.fundingMaxElapsedSec()).to.eq(0)
            await expect(market.connect(owner).setFundingMaxElapsedSec(7 * 24 * 60 * 60))
                .to.emit(market, "FundingMaxElapsedSecChanged")
                .withArgs(7 * 24 * 60 * 60)
            expect(await market.fundingMaxElapsedSec()).to.eq(7 * 24 * 60 * 60)
        })

        it("revert when not owner", async () => {
            await expect(market.connect(alice).setFundingMaxElapsedSec(1)).to.be.revertedWith(
                "Ownable: caller is not the owner",
            )
        })

        it("revert when too large", async () => {
            await expect(market.connect(owner).setFundingMaxElapsedSec(7 * 24 * 60 * 60 + 1)).to.be.revertedWith(
                "PM_SFMES: too large",
            )
        })
    })

    describe("setFundingRolloverSec", () => {
        it("ok", async () => {
            await expect(market.connect(owner).setFundingRolloverSec(60 * 60))
                .to.emit(market, "FundingRolloverSecChanged")
                .withArgs(60 * 60)
            expect(await market.fundingRolloverSec()).to.eq(60 * 60)
            await expect(market.connect(owner).setFundingRolloverSec(7 * 24 * 60 * 60))
                .to.emit(market, "FundingRolloverSecChanged")
                .withArgs(7 * 24 * 60 * 60)
            expect(await market.fundingRolloverSec()).to.eq(7 * 24 * 60 * 60)
        })

        it("revert when not owner", async () => {
            await expect(market.connect(alice).setFundingRolloverSec(1)).to.be.revertedWith(
                "Ownable: caller is not the owner",
            )
        })

        it("revert when too small", async () => {
            await expect(market.connect(owner).setFundingRolloverSec(60 * 60 - 1)).to.be.revertedWith(
                "PM_SFRS: too small",
            )
        })

        it("revert when too large", async () => {
            await expect(market.connect(owner).setFundingRolloverSec(7 * 24 * 60 * 60 + 1)).to.be.revertedWith(
                "PM_SFRS: too large",
            )
        })
    })
})
