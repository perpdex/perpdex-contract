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
            expect(await market.poolFeeRatio()).to.eq(3e3)
            expect(await market.fundingMaxPremiumRatio()).to.eq(1e4)
            expect(await market.fundingMaxElapsedSec()).to.eq(24 * 60 * 60)
            expect(await market.fundingRolloverSec()).to.eq(24 * 60 * 60)
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
