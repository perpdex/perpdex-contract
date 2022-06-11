import { expect } from "chai"
import { parseUnits } from "ethers/lib/utils"
import { ethers, waffle } from "hardhat"
import { PerpdexExchange, TestERC20 } from "../../../typechain"
import { createPerpdexExchangeFixture } from "../fixtures"

describe("Vault withdraw test", () => {
    const [admin, alice, bob] = waffle.provider.getWallets()
    const loadFixture: ReturnType<typeof waffle.createFixtureLoader> = waffle.createFixtureLoader([admin])
    let fixture
    let usdc: TestERC20
    let perpdexExchange: PerpdexExchange
    let usdcDecimals: number

    function parseUsdc(amount: string) {
        return parseUnits(amount, usdcDecimals)
    }

    beforeEach(async () => {
        fixture = await loadFixture(
            createPerpdexExchangeFixture({
                linear: true,
            }),
        )
        perpdexExchange = fixture.perpdexExchange
        usdc = fixture.USDC
        usdcDecimals = await usdc.decimals()

        const amount = parseUsdc("1000")
        await usdc.mint(alice.address, amount)
        await usdc.mint(bob.address, amount)

        await usdc.connect(alice).approve(perpdexExchange.address, ethers.constants.MaxUint256)
        await usdc.connect(bob).approve(perpdexExchange.address, ethers.constants.MaxUint256)
    })

    describe("settlement token", () => {
        it("withdraw settlement token", async () => {
            // alice deposits 300 usdc
            await perpdexExchange.connect(alice).deposit(parseUsdc("300"))

            // bob deposits 150 usdc
            await perpdexExchange.connect(bob).deposit(parseUsdc("150"))

            // alice withdraws 100 usdc
            await perpdexExchange.connect(alice).withdraw(parseUsdc("100"))

            // change alice balance
            // alice usdc balance is 1000 - 300 + 100 = 800
            expect(await usdc.balanceOf(alice.address)).to.eq(parseUsdc("800"))

            // change vault balance
            // vault usdc balance is 300(alice) + 150(bob) - 100(alice) = 350
            expect(await usdc.balanceOf(perpdexExchange.address)).to.eq(parseUsdc("350"))

            // update alice perpdex account balance
            // alice account collateralBalance is 200 = 300 - 100
            const result = await perpdexExchange.accountInfos(alice.address)
            expect(result.collateralBalance).to.eq(parseUsdc("200").mul(1e12))
        })

        it("force error, not enough balance to withdraw", async () => {
            await perpdexExchange.connect(alice).deposit(parseUsdc("100"))
            await expect(perpdexExchange.connect(alice).withdraw(parseUsdc("101"))).to.be.revertedWith(
                "VL_W: not enough initial margin",
            )
        })

        it("force error, zero amount", async () => {
            await expect(perpdexExchange.connect(alice).withdraw("0")).to.be.revertedWith("VL_W: zero amount")
        })

        // TODO: will write this after trade test
        it("reverts when account does not have enough initial margin")
    })
})
