import { expect } from "chai"
import { parseUnits } from "ethers/lib/utils"
import { ethers, waffle } from "hardhat"
import { PerpdexExchange, TestERC20 } from "../../../typechain"
import { createPerpdexExchangeFixture } from "../fixtures"

describe("Vault deposit eth", () => {
    const [admin, alice] = waffle.provider.getWallets()
    const loadFixture: ReturnType<typeof waffle.createFixtureLoader> = waffle.createFixtureLoader([admin])
    let fixture
    let exchange: PerpdexExchange

    beforeEach(async () => {
        fixture = await loadFixture(createPerpdexExchangeFixture())
        exchange = fixture.perpdexExchange
    })

    describe("deposit", () => {
        it("ok", async () => {
            const res = await exchange.connect(alice).deposit(0, { value: 100 })
            await expect(res).to.changeEtherBalance(alice, -100)
            await expect(res).to.emit(exchange, "Deposited").withArgs(alice.address, 100)

            const result = await exchange.accountInfos(alice.address)
            expect(result.collateralBalance).to.eq(100)
        })

        it("force error, amount is not zero", async () => {
            await expect(exchange.connect(alice).deposit(100, { value: 100 })).to.be.revertedWith(
                "PE_D: amount not zero",
            )
        })

        it("force error, zero amount", async () => {
            await expect(exchange.connect(alice).deposit(0, { value: 0 })).to.be.revertedWith("VL_DE: zero amount")
        })
    })
})
