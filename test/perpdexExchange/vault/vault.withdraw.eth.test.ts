import { expect } from "chai"
import { parseUnits } from "ethers/lib/utils"
import { ethers, waffle } from "hardhat"
import { PerpdexExchange, TestERC20 } from "../../../typechain"
import { createPerpdexExchangeFixture } from "../fixtures"

describe("Vault withdraw eth", () => {
    const [admin, alice, bob] = waffle.provider.getWallets()
    const loadFixture: ReturnType<typeof waffle.createFixtureLoader> = waffle.createFixtureLoader([admin])
    let fixture
    let exchange: PerpdexExchange

    beforeEach(async () => {
        fixture = await loadFixture(createPerpdexExchangeFixture())
        exchange = fixture.perpdexExchange
    })

    describe("withdraw", async () => {
        it("ok", async () => {
            await exchange.connect(alice).deposit(0, { value: 100 })

            const res = await exchange.connect(alice).withdraw(30)
            await expect(res).to.changeEtherBalance(alice, 30)
            await expect(res).to.emit(exchange, "Withdrawn").withArgs(alice.address, 30)

            const result = await exchange.accountInfos(alice.address)
            expect(result.collateralBalance).to.eq(70)
        })

        it("force error, not enough balance to withdraw", async () => {
            await exchange.connect(alice).deposit(0, { value: 100 })
            await expect(exchange.connect(alice).withdraw(101)).to.be.revertedWith("VL_W: not enough initial margin")
        })

        it("force error, zero amount", async () => {
            await expect(exchange.connect(alice).withdraw(0)).to.be.revertedWith("VL_W: zero amount")
        })
    })
})
