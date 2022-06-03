import { expect } from "chai"
import { parseUnits } from "ethers/lib/utils"
import { ethers, waffle } from "hardhat"
import { PerpdexMarket } from "../../typechain"
import { createPerpdexMarketFixture } from "./fixtures"
import { Wallet } from "ethers"

describe("PerpdexMarket config test", () => {
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

    describe("initial values", async () => {
        it("ok", async () => {
            expect(await market.poolFeeRatio()).to.eq(3e3)
        })
    })

    describe("setPoolFeeRatio", async () => {
        it("ok", async () => {
            await market.connect(owner).setPoolFeeRatio(1)
            expect(await market.poolFeeRatio()).to.eq(1)
        })

        it("revert when not owner", async () => {
            await expect(market.connect(alice).setPoolFeeRatio(1)).to.be.revertedWith(
                "Ownable: caller is not the owner",
            )
        })

        it("revert when too large", async () => {
            await expect(market.connect(owner).setPoolFeeRatio(1e6)).to.be.revertedWith("PerpdexMarket: too large")
        })
    })
})
