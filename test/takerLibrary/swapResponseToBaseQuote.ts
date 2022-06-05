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

    describe("swapResponseToBaseQuote", async () => {
        ;[
            {
                title: "exact input long",
                isBaseToQuote: false,
                isExactInput: true,
                amount: 1,
                oppositeAmount: 2,
                base: 2,
                quote: -1,
            },
            {
                title: "exact input short",
                isBaseToQuote: true,
                isExactInput: true,
                amount: 1,
                oppositeAmount: 2,
                base: -1,
                quote: 2,
            },
            {
                title: "exact output long",
                isBaseToQuote: false,
                isExactInput: false,
                amount: 1,
                oppositeAmount: 2,
                base: 1,
                quote: -2,
            },
            {
                title: "exact output short",
                isBaseToQuote: true,
                isExactInput: false,
                amount: 1,
                oppositeAmount: 2,
                base: -2,
                quote: 1,
            },
        ].forEach(test => {
            it(test.title, async () => {
                const res = await library.swapResponseToBaseQuote(
                    test.isBaseToQuote,
                    test.isExactInput,
                    test.amount,
                    test.oppositeAmount,
                )
                expect(res[0]).to.eq(test.base)
                expect(res[1]).to.eq(test.quote)
            })
        })
    })
})
