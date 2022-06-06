import { expect } from "chai"
import { waffle } from "hardhat"
import { TestTakerLibrary } from "../../typechain"
import { createTakerLibraryFixture } from "./fixtures"
import { BigNumberish } from "ethers"

describe("TakerLibrary", () => {
    let loadFixture = waffle.createFixtureLoader(waffle.provider.getWallets())
    let fixture

    let library: TestTakerLibrary

    beforeEach(async () => {
        fixture = await loadFixture(createTakerLibraryFixture())
        library = fixture.takerLibrary
    })

    describe("processLiquidationFee", () => {
        ;[
            {
                title: "normal",
                collateralBalance: 100,
                liquidatorCollateralBalance: 200,
                insuranceFundBalance: 300,
                mmRatio: 20e4,
                liquidationRewardRatio: 25e4,
                exchangedQuote: 100,
                liquidationReward: 5,
                insuranceFundReward: 15,
                revertedWith: void 0,
            },
            {
                title: "rounding",
                collateralBalance: 100,
                liquidatorCollateralBalance: 200,
                insuranceFundBalance: 300,
                mmRatio: 20e4,
                liquidationRewardRatio: 25e4,
                exchangedQuote: 99,
                liquidationReward: 4,
                insuranceFundReward: 15,
                revertedWith: void 0,
            },
            {
                title: "negative",
                collateralBalance: 0,
                liquidatorCollateralBalance: 0,
                insuranceFundBalance: 0,
                mmRatio: 20e4,
                liquidationRewardRatio: 25e4,
                exchangedQuote: 100,
                liquidationReward: 5,
                insuranceFundReward: 15,
                revertedWith: void 0,
            },
        ].forEach(test => {
            it(test.title, async () => {
                await library.setAccountInfo({ collateralBalance: test.collateralBalance }, [])
                await library.setLiquidatorVaultInfo({ collateralBalance: test.liquidatorCollateralBalance })
                await library.setInsuranceFundInfo({ balance: test.insuranceFundBalance })

                const res = expect(
                    library.processLiquidationFee(test.mmRatio, test.liquidationRewardRatio, test.exchangedQuote),
                )

                if (test.revertedWith === void 0) {
                    await res.to
                        .emit(library, "ProcessLiquidationFeeResult")
                        .withArgs(test.liquidationReward, test.insuranceFundReward)

                    const vault = await library.accountInfo()
                    expect(vault.collateralBalance).to.eq(
                        test.collateralBalance - test.liquidationReward - test.insuranceFundReward,
                    )
                    const liquidatorBalance = await library.liquidatorVaultInfo()
                    expect(liquidatorBalance).to.eq(test.liquidatorCollateralBalance + test.liquidationReward)
                    const insuranceFundBalance = await library.insuranceFundInfo()
                    expect(insuranceFundBalance).to.eq(test.insuranceFundBalance + test.insuranceFundReward)
                } else {
                    await res.to.revertedWith(test.revertedWith)
                }
            })
        })
    })
})
