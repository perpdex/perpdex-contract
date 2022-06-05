import { expect } from "chai"
import { waffle } from "hardhat"
import { TestTakerLibrary } from "../../typechain"
import { createTakerLibraryFixture } from "./fixtures"

describe("TakerLibrary", () => {
    let loadFixture = waffle.createFixtureLoader(waffle.provider.getWallets())
    let fixture

    let library: TestTakerLibrary

    beforeEach(async () => {
        fixture = await loadFixture(createTakerLibraryFixture())
        library = fixture.takerLibrary
    })

    describe("validateSlippage", async () => {
        ;[
            {
                title: "exact input same",
                isExactInput: true,
                oppositeAmount: 100,
                oppositeAmountBound: 100,
                revertedWith: void 0,
            },
            {
                title: "exact input smaller",
                isExactInput: true,
                oppositeAmount: 99,
                oppositeAmountBound: 100,
                revertedWith: "TL_VS: too small opposite amount",
            },
            {
                title: "exact input larger",
                isExactInput: true,
                oppositeAmount: 101,
                oppositeAmountBound: 100,
                revertedWith: void 0,
            },
            {
                title: "exact output same",
                isExactInput: false,
                oppositeAmount: 100,
                oppositeAmountBound: 100,
                revertedWith: void 0,
            },
            {
                title: "exact output smaller",
                isExactInput: false,
                oppositeAmount: 99,
                oppositeAmountBound: 100,
                revertedWith: void 0,
            },
            {
                title: "exact output larger",
                isExactInput: false,
                oppositeAmount: 101,
                oppositeAmountBound: 100,
                revertedWith: "TL_VS: too large opposite amount",
            },
        ].forEach(test => {
            it(test.title, async () => {
                const res = expect(
                    library.validateSlippage(test.isExactInput, test.oppositeAmount, test.oppositeAmountBound),
                )

                if (test.revertedWith === void 0) {
                    await res.not.to.reverted
                } else {
                    await res.to.revertedWith(test.revertedWith)
                }
            })
        })
    })
})
