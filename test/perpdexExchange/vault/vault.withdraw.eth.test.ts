import { expect } from "chai"
import { parseUnits } from "ethers/lib/utils"
import { ethers, waffle } from "hardhat"
import { TestPerpdexExchange, TestPerpdexMarket, TestERC20 } from "../../../typechain"
import { createPerpdexExchangeFixture } from "../fixtures"
import { BigNumber } from "ethers"

describe("Vault withdraw eth", () => {
    const [admin, alice, bob] = waffle.provider.getWallets()
    const loadFixture: ReturnType<typeof waffle.createFixtureLoader> = waffle.createFixtureLoader([admin])
    let fixture
    let exchange: TestPerpdexExchange
    let market: TestPerpdexMarket

    const Q96 = BigNumber.from(2).pow(96)

    beforeEach(async () => {
        fixture = await loadFixture(createPerpdexExchangeFixture())
        exchange = fixture.perpdexExchange
        market = fixture.perpdexMarket
    })

    describe("withdraw", () => {
        it("ok", async () => {
            await exchange.connect(alice).deposit(0, { value: 100 })

            const res = await exchange.connect(alice).withdraw(30)
            await expect(res).to.changeEtherBalance(alice, 30)
            await expect(res).to.emit(exchange, "Withdrawn").withArgs(alice.address, 30)

            const result = await exchange.accountInfos(alice.address)
            expect(result.collateralBalance).to.eq(70)
        })

        it("low account value", async () => {
            await exchange.setAccountInfo(alice.address, { collateralBalance: 0 }, [market.address])
            await exchange.setTakerInfo(alice.address, market.address, {
                baseBalanceShare: -100,
                quoteBalance: 0,
            })
            await market.setPoolInfo({
                base: 10000,
                quote: 10000,
                totalLiquidity: 10000,
                cumDeleveragedBasePerLiquidityX96: 0,
                cumDeleveragedQuotePerLiquidityX96: 0,
                baseBalancePerShareX96: Q96,
            })

            await exchange.connect(alice).deposit(0, { value: 100 })
            await expect(exchange.connect(alice).withdraw(1)).to.revertedWith("VL_W: not enough initial margin")
        })

        it("profit but no collateral", async () => {
            await exchange.setAccountInfo(alice.address, { collateralBalance: 0 }, [market.address])
            await exchange.setTakerInfo(alice.address, market.address, {
                baseBalanceShare: 100,
                quoteBalance: 0,
            })
            await market.setPoolInfo({
                base: 10000,
                quote: 10000,
                totalLiquidity: 10000,
                cumDeleveragedBasePerLiquidityX96: 0,
                cumDeleveragedQuotePerLiquidityX96: 0,
                baseBalancePerShareX96: Q96,
            })

            await exchange.connect(bob).deposit(0, { value: 100 })
            await expect(exchange.connect(alice).withdraw(1)).to.revertedWith("VL_W: not enough initial margin")
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
