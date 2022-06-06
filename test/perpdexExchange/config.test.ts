import { expect } from "chai"
import { waffle } from "hardhat"
import { TestPerpdexExchange, TestPerpdexMarket } from "../../typechain"
import { createPerpdexExchangeFixture } from "./fixtures"
import { Wallet } from "ethers"

describe("PerpdexExchange config", () => {
    let loadFixture = waffle.createFixtureLoader(waffle.provider.getWallets())
    let fixture

    let exchange: TestPerpdexExchange
    let market: TestPerpdexMarket
    let owner: Wallet
    let alice: Wallet

    beforeEach(async () => {
        fixture = await loadFixture(createPerpdexExchangeFixture())
        exchange = fixture.perpdexExchange
        market = fixture.perpdexMarket
        owner = fixture.owner
        alice = fixture.alice
    })

    describe("initial values", () => {
        it("ok", async () => {
            const priceLimitConfig = await exchange.priceLimitConfig()
            expect(priceLimitConfig.normalOrderRatio).to.eq(5e4)
            expect(priceLimitConfig.liquidationRatio).to.eq(10e4)
            expect(await exchange.maxMarketsPerAccount()).to.eq(16)
            expect(await exchange.imRatio()).to.eq(10e4)
            expect(await exchange.mmRatio()).to.eq(5e4)
            expect(await exchange.liquidationRewardRatio()).to.eq(20e4)
            expect(await exchange.protocolFeeRatio()).to.eq(0)
        })
    })

    describe("setPriceLimitConfig", () => {
        it("ok", async () => {
            await exchange.connect(owner).setPriceLimitConfig({
                normalOrderRatio: 0,
                liquidationRatio: 0,
            })
            let priceLimitConfig = await exchange.priceLimitConfig()
            expect(priceLimitConfig.normalOrderRatio).to.eq(0)
            expect(priceLimitConfig.liquidationRatio).to.eq(0)

            await exchange.connect(owner).setPriceLimitConfig({
                normalOrderRatio: 1,
                liquidationRatio: 5e5,
            })
            priceLimitConfig = await exchange.priceLimitConfig()
            expect(priceLimitConfig.normalOrderRatio).to.eq(1)
            expect(priceLimitConfig.liquidationRatio).to.eq(5e5)
        })

        it("revert when not owner", async () => {
            await expect(
                exchange.connect(alice).setPriceLimitConfig({
                    normalOrderRatio: 0,
                    liquidationRatio: 0,
                }),
            ).to.be.revertedWith("Ownable: caller is not the owner")
        })

        it("revert when too large", async () => {
            await expect(
                exchange.connect(owner).setPriceLimitConfig({
                    normalOrderRatio: 0,
                    liquidationRatio: 5e5 + 1,
                }),
            ).to.be.revertedWith("PE_SPLC: too large liquidation")
        })

        it("revert when normal order > liquidation", async () => {
            await expect(
                exchange.connect(owner).setPriceLimitConfig({
                    normalOrderRatio: 2,
                    liquidationRatio: 1,
                }),
            ).to.be.revertedWith("PE_SPLC: invalid")
        })
    })

    describe("setMaxMarketsPerAccount", () => {
        it("ok", async () => {
            await exchange.connect(owner).setMaxMarketsPerAccount(0)
            expect(await exchange.maxMarketsPerAccount()).to.eq(0)
            await exchange.connect(owner).setMaxMarketsPerAccount(255)
            expect(await exchange.maxMarketsPerAccount()).to.eq(255)
        })

        it("revert when not owner", async () => {
            await expect(exchange.connect(alice).setMaxMarketsPerAccount(1)).to.be.revertedWith(
                "Ownable: caller is not the owner",
            )
        })
    })

    describe("setImRatio", () => {
        it("ok", async () => {
            await exchange.connect(owner).setImRatio(5e4)
            expect(await exchange.imRatio()).to.eq(5e4)
            await exchange.connect(owner).setImRatio(1e6 - 1)
            expect(await exchange.imRatio()).to.eq(1e6 - 1)
        })

        it("revert when not owner", async () => {
            await expect(exchange.connect(alice).setImRatio(5e4)).to.be.revertedWith("Ownable: caller is not the owner")
        })

        it("revert when too large", async () => {
            await expect(exchange.connect(owner).setImRatio(1e6)).to.be.revertedWith("PE_SIR: too large")
        })

        it("revert when smaller than mm", async () => {
            await expect(exchange.connect(owner).setImRatio(5e4 - 1)).to.be.revertedWith("PE_SIR: smaller than mmRatio")
        })
    })

    describe("setMmRatio", () => {
        it("ok", async () => {
            await exchange.connect(owner).setMmRatio(1)
            expect(await exchange.mmRatio()).to.eq(1)
            await exchange.connect(owner).setMmRatio(10e4)
            expect(await exchange.mmRatio()).to.eq(10e4)
        })

        it("revert when not owner", async () => {
            await expect(exchange.connect(alice).setMmRatio(1)).to.be.revertedWith("Ownable: caller is not the owner")
        })

        it("revert when too large", async () => {
            await expect(exchange.connect(owner).setMmRatio(10e4 + 1)).to.be.revertedWith("PE_SMR: bigger than imRatio")
        })

        it("revert when zero", async () => {
            await expect(exchange.connect(owner).setMmRatio(0)).to.be.revertedWith("PE_SMR: zero")
        })
    })

    describe("setLiquidationRewardRatio", () => {
        it("ok", async () => {
            await exchange.connect(owner).setLiquidationRewardRatio(0)
            expect(await exchange.liquidationRewardRatio()).to.eq(0)
            await exchange.connect(owner).setLiquidationRewardRatio(1e6 - 1)
            expect(await exchange.liquidationRewardRatio()).to.eq(1e6 - 1)
        })

        it("revert when not owner", async () => {
            await expect(exchange.connect(alice).setLiquidationRewardRatio(1)).to.be.revertedWith(
                "Ownable: caller is not the owner",
            )
        })

        it("revert when too large", async () => {
            await expect(exchange.connect(owner).setLiquidationRewardRatio(1e6)).to.be.revertedWith(
                "PE_SLRR: too large",
            )
        })
    })

    describe("setProtocolFeeRatio", () => {
        it("ok", async () => {
            await exchange.connect(owner).setProtocolFeeRatio(0)
            expect(await exchange.protocolFeeRatio()).to.eq(0)
            await exchange.connect(owner).setProtocolFeeRatio(1e4)
            expect(await exchange.protocolFeeRatio()).to.eq(1e4)
        })

        it("revert when not owner", async () => {
            await expect(exchange.connect(alice).setProtocolFeeRatio(1)).to.be.revertedWith(
                "Ownable: caller is not the owner",
            )
        })

        it("revert when too large", async () => {
            await expect(exchange.connect(owner).setProtocolFeeRatio(1e4 + 1)).to.be.revertedWith("PE_SPFR: too large")
        })
    })

    describe("setIsMarketAllowed", () => {
        it("enable", async () => {
            await expect(exchange.connect(owner).setIsMarketAllowed(market.address, true))
                .to.emit(exchange, "IsMarketAllowedChanged")
                .withArgs(market.address, true)
            expect(await exchange.isMarketAllowed(market.address)).to.eq(true)
            await expect(exchange.connect(owner).setIsMarketAllowed(market.address, true)).not.to.emit(
                exchange,
                "IsMarketAllowedChanged",
            )
        })

        it("disable", async () => {
            await exchange.connect(owner).setIsMarketAllowed(market.address, true)

            await expect(exchange.connect(owner).setIsMarketAllowed(market.address, false))
                .to.emit(exchange, "IsMarketAllowedChanged")
                .withArgs(market.address, false)
            expect(await exchange.isMarketAllowed(market.address)).to.eq(false)
            await expect(exchange.connect(owner).setIsMarketAllowed(market.address, false)).not.to.emit(
                exchange,
                "IsMarketAllowedChanged",
            )
        })

        it("revert when not owner", async () => {
            await expect(exchange.connect(alice).setIsMarketAllowed(market.address, true)).to.be.revertedWith(
                "Ownable: caller is not the owner",
            )
        })

        it("revert when invalid address", async () => {
            await expect(exchange.connect(owner).setIsMarketAllowed(alice.address, true)).to.be.revertedWith(
                "PE_SIMA: market address invalid",
            )
        })
    })
})
