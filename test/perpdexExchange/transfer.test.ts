import { expect } from "chai"
import { parseUnits } from "ethers/lib/utils"
import { ethers, waffle } from "hardhat"
import { TestPerpdexExchange, TestERC20 } from "../../typechain"
import { createPerpdexExchangeFixture } from "./fixtures"
import { Wallet } from "ethers"

describe("PerpdexExchange transfer", () => {
    let loadFixture = waffle.createFixtureLoader(waffle.provider.getWallets())
    let fixture
    let exchange: TestPerpdexExchange
    let owner: Wallet

    beforeEach(async () => {
        fixture = await loadFixture(createPerpdexExchangeFixture())
        exchange = fixture.perpdexExchange
        owner = fixture.owner
    })

    describe("transferInsuranceFund", async () => {
        it("ok", async () => {
            await exchange.setInsuranceFundInfo({
                balance: 100,
            })
            await expect(exchange.connect(owner).transferInsuranceFund(30))
                .to.emit(exchange, "InsuranceFundTransferred")
                .withArgs(owner.address, 30)

            const balance = await exchange.insuranceFundInfo()
            expect(balance).to.eq(70)

            const result = await exchange.accountInfos(owner.address)
            expect(result.collateralBalance).to.eq(30)
        })

        it("force error, not enough balance", async () => {
            await expect(exchange.connect(owner).transferInsuranceFund(30)).to.revertedWith("VL_TIF: negative balance")
        })
    })

    describe("transferProtocolFee", async () => {
        it("ok", async () => {
            await exchange.setProtocolInfo({
                protocolFee: 100,
            })
            await expect(exchange.connect(owner).transferProtocolFee(30))
                .to.emit(exchange, "ProtocolFeeTransferred")
                .withArgs(owner.address, 30)

            const balance = await exchange.protocolInfo()
            expect(balance).to.eq(70)

            const result = await exchange.accountInfos(owner.address)
            expect(result.collateralBalance).to.eq(30)
        })

        it("force error, not enough balance", async () => {
            await expect(exchange.connect(owner).transferProtocolFee(30)).to.revertedWith(
                "SafeMath: subtraction overflow",
            )
        })
    })
})
