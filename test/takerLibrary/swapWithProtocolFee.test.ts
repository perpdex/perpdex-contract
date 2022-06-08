import { expect } from "chai"
import { waffle } from "hardhat"
import { TestTakerLibrary } from "../../typechain"
import { createTakerLibraryFixture } from "./fixtures"
import { BigNumberish } from "ethers"
import { MockContract } from "ethereum-waffle"

describe("TakerLibrary", () => {
    let loadFixture = waffle.createFixtureLoader(waffle.provider.getWallets())
    let fixture

    let library: TestTakerLibrary
    let market: MockContract

    beforeEach(async () => {
        fixture = await loadFixture(createTakerLibraryFixture())
        library = fixture.takerLibrary
        market = fixture.market
    })

    describe("swapWithProtocolFee", () => {
        ;[
            {
                title: "exact input long",
                protocolFeeBalance: 1,
                isBaseToQuote: false,
                isExactInput: true,
                amount: 1000,
                protocolFeeRatio: 2e5,
                swapAmount: 800,
                swapOppositeAmount: 80,
                oppositeAmount: 80,
                protocolFee: 200,
                revertedWith: void 0,
            },
            {
                title: "exact input short",
                protocolFeeBalance: 1,
                isBaseToQuote: true,
                isExactInput: true,
                amount: 1000,
                protocolFeeRatio: 2e5,
                swapAmount: 1000,
                swapOppositeAmount: 100,
                oppositeAmount: 80,
                protocolFee: 20,
                revertedWith: void 0,
            },
            {
                title: "exact output long",
                protocolFeeBalance: 1,
                isBaseToQuote: false,
                isExactInput: false,
                amount: 80,
                protocolFeeRatio: 2e5,
                swapAmount: 80,
                swapOppositeAmount: 800,
                oppositeAmount: 1000,
                protocolFee: 200,
                revertedWith: void 0,
            },
            {
                title: "exact output short",
                protocolFeeBalance: 1,
                isBaseToQuote: true,
                isExactInput: false,
                amount: 80,
                protocolFeeRatio: 2e5,
                swapAmount: 100,
                swapOppositeAmount: 1000,
                oppositeAmount: 1000,
                protocolFee: 20,
                revertedWith: void 0,
            },
        ].forEach(test => {
            it(test.title, async () => {
                await market.mock.swap
                    .withArgs(test.isBaseToQuote, test.isExactInput, test.swapAmount, false)
                    .returns(test.swapOppositeAmount)

                await library.setProtocolInfo({ protocolFee: test.protocolFeeBalance })

                const res = expect(
                    library.swapWithProtocolFee(
                        market.address,
                        test.isBaseToQuote,
                        test.isExactInput,
                        test.amount,
                        test.protocolFeeRatio,
                        false,
                    ),
                )

                if (test.revertedWith === void 0) {
                    await res.to
                        .emit(library, "SwapWithProtocolFeeResult")
                        .withArgs(test.oppositeAmount, test.protocolFee)

                    const protocolFeeBalance = await library.protocolInfo()
                    expect(protocolFeeBalance).to.eq(test.protocolFeeBalance + test.protocolFee)
                } else {
                    await res.to.revertedWith(test.revertedWith)
                }
            })

            it(test.title + " dry", async () => {
                await market.mock.swapDry
                    .withArgs(test.isBaseToQuote, test.isExactInput, test.swapAmount, false)
                    .returns(test.swapOppositeAmount)

                const res = await library.swapWithProtocolFeeDry(
                    market.address,
                    test.isBaseToQuote,
                    test.isExactInput,
                    test.amount,
                    test.protocolFeeRatio,
                    false,
                )

                expect(res[0]).to.eq(test.oppositeAmount)
                expect(res[1]).to.eq(test.protocolFee)
            })
        })
    })
})
