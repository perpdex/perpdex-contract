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

    describe("processLiquidationReward", () => {
        ;[
            {
                title: "normal",
                collateralBalance: 100,
                liquidatorCollateralBalance: 200,
                insuranceFundBalance: 300,
                mmRatio: 20e4,
                rewardRatio: 25e4,
                smoothEmaTime: 1,
                exchangedQuote: 100,
                penalty: 20,
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
                rewardRatio: 25e4,
                smoothEmaTime: 1,
                exchangedQuote: 99,
                penalty: 19,
                liquidationReward: 4,
                insuranceFundReward: 15,
                revertedWith: void 0,
            },
            {
                title: "smoothing",
                collateralBalance: 0,
                liquidatorCollateralBalance: 0,
                insuranceFundBalance: 0,
                liquidationRewardBalance: 95,
                mmRatio: 20e4,
                rewardRatio: 25e4,
                smoothEmaTime: 8,
                exchangedQuote: 100,
                penalty: 20,
                liquidationReward: 12,
                insuranceFundReward: 15,
                afterLiquidationRewardBalance: 88,
                revertedWith: void 0,
            },
        ].forEach(test => {
            it(test.title, async () => {
                await library.setAccountInfo({ collateralBalance: test.collateralBalance }, [])
                await library.setLiquidatorVaultInfo({ collateralBalance: test.liquidatorCollateralBalance })
                await library.setInsuranceFundInfo({
                    balance: test.insuranceFundBalance,
                    liquidationRewardBalance: test.liquidationRewardBalance || 0,
                })

                const res = expect(
                    library.processLiquidationReward(
                        test.mmRatio,
                        {
                            rewardRatio: test.rewardRatio,
                            smoothEmaTime: test.smoothEmaTime,
                        },
                        test.exchangedQuote,
                    ),
                )

                if (test.revertedWith === void 0) {
                    await res.to
                        .emit(library, "ProcessLiquidationRewardResult")
                        .withArgs(test.penalty, test.liquidationReward, test.insuranceFundReward)

                    const vault = await library.accountInfo()
                    expect(vault.collateralBalance).to.eq(test.collateralBalance - test.penalty)
                    const liquidatorBalance = await library.liquidatorVaultInfo()
                    expect(liquidatorBalance).to.eq(test.liquidatorCollateralBalance + test.liquidationReward)
                    const fundInfo = await library.insuranceFundInfo()
                    expect(fundInfo.balance).to.eq(test.insuranceFundBalance + test.insuranceFundReward)
                    expect(fundInfo.liquidationRewardBalance).to.eq(test.afterLiquidationRewardBalance || 0)
                } else {
                    await res.to.revertedWith(test.revertedWith)
                }
            })
        })
    })
})
