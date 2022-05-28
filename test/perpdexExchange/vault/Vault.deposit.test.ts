import { MockContract } from "@eth-optimism/smock"
import { expect } from "chai"
import { parseEther, parseUnits } from "ethers/lib/utils"
import { ethers, waffle } from "hardhat"
import { PerpdexExchange, TestERC20 } from "../../../typechain"
import { createPerpdexExchangeFixture } from "../fixtures"

describe("Vault deposit test", () => {
    const [admin, alice, bob] = waffle.provider.getWallets()
    const loadFixture: ReturnType<typeof waffle.createFixtureLoader> = waffle.createFixtureLoader([admin])
    let usdc: TestERC20
    let perpdexExchange: PerpdexExchange
    let usdcDecimals: number
    let fixture

    beforeEach(async () => {
        const _fixture = await loadFixture(createPerpdexExchangeFixture())
        perpdexExchange = _fixture.perpdexExchange
        usdc = _fixture.USDC
        fixture = _fixture

        usdcDecimals = await usdc.decimals()
        const amount = parseUnits("1000", usdcDecimals)
        await usdc.mint(alice.address, amount)

        await usdc.connect(alice).approve(perpdexExchange.address, ethers.constants.MaxUint256)
    })

    describe("settlement token", async () => {
        let usdcDecimals

        beforeEach(async () => {
            usdcDecimals = await usdc.decimals()
        })

        it("deposit settlement token", async () => {
            const amount = parseUnits("100", usdcDecimals)

            // check event has been sent
            await expect(perpdexExchange.connect(alice).deposit(amount))
                .to.emit(perpdexExchange, "Deposited")
                .withArgs(alice.address, amount)

            // reduce alice balance
            expect(await usdc.balanceOf(alice.address)).to.eq(parseUnits("900", usdcDecimals))

            // increase vault balance
            expect(await usdc.balanceOf(perpdexExchange.address)).to.eq(amount)

            // update sender's balance
            const result = await perpdexExchange.accountInfos(alice.address)
            expect(result.collateralBalance).to.eq(amount)
        })

        it("force error, not enough balance", async () => {
            const amount = parseUnits("1100", await usdc.decimals())
            await expect(perpdexExchange.connect(alice).deposit(amount)).to.be.revertedWith(
                "ERC20: transfer amount exceeds balance",
            )
        })

        it("force error, inconsistent vault balance with deflationary token", async () => {
            usdc.setTransferFeeRatio(50)
            await expect(perpdexExchange.connect(alice).deposit(parseUnits("100", usdcDecimals))).to.be.revertedWith(
                "V_IBA",
            )
            usdc.setTransferFeeRatio(0)
        })

        it("force error, zero amount", async () => {
            await expect(perpdexExchange.connect(alice).deposit("0")).to.be.revertedWith("V_ZA")
        })
    })
})
