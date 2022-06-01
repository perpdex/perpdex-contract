import { expect } from "chai"
import { parseUnits } from "ethers/lib/utils"
import { ethers, waffle } from "hardhat"
import { PerpdexExchange, TestERC20 } from "../../../typechain"
import { createPerpdexExchangeFixture } from "../fixtures"

describe("Vault deposit test", () => {
    const [admin, alice] = waffle.provider.getWallets()
    const loadFixture: ReturnType<typeof waffle.createFixtureLoader> = waffle.createFixtureLoader([admin])
    let fixture
    let usdc: TestERC20
    let perpdexExchange: PerpdexExchange
    let usdcDecimals: number

    function parseUsdc(amount: string) {
        return parseUnits(amount, usdcDecimals)
    }

    beforeEach(async () => {
        fixture = await loadFixture(createPerpdexExchangeFixture())
        perpdexExchange = fixture.perpdexExchange
        usdc = fixture.USDC
        usdcDecimals = await usdc.decimals()

        const amount = parseUsdc("1000")
        await usdc.mint(alice.address, amount)

        await usdc.connect(alice).approve(perpdexExchange.address, ethers.constants.MaxUint256)
    })

    describe("settlement token", async () => {
        it("deposit settlement token", async () => {
            const amount = parseUsdc("100")

            // check event has been sent
            await expect(perpdexExchange.connect(alice).deposit(amount))
                .to.emit(perpdexExchange, "Deposited")
                .withArgs(alice.address, amount)

            // reduce alice balance
            expect(await usdc.balanceOf(alice.address)).to.eq(parseUsdc("900"))

            // increase vault balance
            expect(await usdc.balanceOf(perpdexExchange.address)).to.eq(amount)

            // update sender's balance
            const result = await perpdexExchange.accountInfos(alice.address)
            expect(result.collateralBalance).to.eq(amount)
        })

        it("force error, not enough balance", async () => {
            const amount = parseUsdc("1100")
            await expect(perpdexExchange.connect(alice).deposit(amount)).to.be.revertedWith(
                "ERC20: transfer amount exceeds balance",
            )
        })

        it("force error, inconsistent vault balance with deflationary token", async () => {
            usdc.setTransferFeeRatio(50)
            await expect(perpdexExchange.connect(alice).deposit(parseUsdc("100"))).to.be.revertedWith("V_IBA")
            usdc.setTransferFeeRatio(0)
        })

        it("force error, zero amount", async () => {
            await expect(perpdexExchange.connect(alice).deposit(parseUsdc("0"))).to.be.revertedWith("V_ZA")
        })
    })
})
