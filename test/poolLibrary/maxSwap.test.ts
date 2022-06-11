import { expect } from "chai"
import { waffle } from "hardhat"
import { TestPoolLibrary } from "../../typechain"
import { createPoolLibraryFixture } from "./fixtures"
import { BigNumber, BigNumberish, Wallet } from "ethers"
import { MockContract } from "ethereum-waffle"

describe("PoolLibrary maxSwap", () => {
    let loadFixture = waffle.createFixtureLoader(waffle.provider.getWallets())
    let fixture

    let library: TestPoolLibrary

    const Q96 = BigNumber.from(2).pow(96)

    beforeEach(async () => {
        fixture = await loadFixture(createPoolLibraryFixture())
        library = fixture.poolLibrary
    })

    describe("various cases", () => {
        ;[
            {
                title: "long exact input",
                base: 100,
                quote: 100,
                isBaseToQuote: false,
                isExactInput: true,
                feeRatio: 0,
                priceBoundX96: Q96.mul(4),
                expected: 100,
            },
            {
                title: "short exact input",
                base: 100,
                quote: 100,
                isBaseToQuote: true,
                isExactInput: true,
                feeRatio: 0,
                priceBoundX96: Q96.div(4),
                expected: 100,
            },
            {
                title: "long exact output",
                base: 100,
                quote: 100,
                isBaseToQuote: false,
                isExactInput: false,
                feeRatio: 0,
                priceBoundX96: Q96.mul(4),
                expected: 50,
            },
            {
                title: "short exact output",
                base: 100,
                quote: 100,
                isBaseToQuote: true,
                isExactInput: false,
                feeRatio: 0,
                priceBoundX96: Q96.div(4),
                expected: 50,
            },
            {
                title: "long at price bound",
                base: 100,
                quote: 100,
                isBaseToQuote: false,
                isExactInput: true,
                feeRatio: 0,
                priceBoundX96: Q96,
                expected: 0,
            },
            {
                title: "short at price bound",
                base: 100,
                quote: 100,
                isBaseToQuote: true,
                isExactInput: true,
                feeRatio: 0,
                priceBoundX96: Q96,
                expected: 0,
            },
            {
                title: "long above price bound",
                base: 100,
                quote: 100,
                isBaseToQuote: false,
                isExactInput: true,
                feeRatio: 0,
                priceBoundX96: Q96.div(2),
                expected: 0,
            },
            {
                title: "short below price bound",
                base: 100,
                quote: 100,
                isBaseToQuote: true,
                isExactInput: true,
                feeRatio: 0,
                priceBoundX96: Q96.mul(2),
                expected: 0,
            },
            {
                title: "long exact output too small",
                base: Q96,
                quote: Q96,
                isBaseToQuote: false,
                isExactInput: false,
                feeRatio: 0,
                priceBoundX96: Q96.add(1),
                expected: 0,
            },
            {
                title: "short exact output too small",
                base: Q96,
                quote: Q96,
                isBaseToQuote: true,
                isExactInput: false,
                feeRatio: 0,
                priceBoundX96: Q96.sub(1),
                expected: 0,
            },
        ].forEach(test => {
            it(test.title, async () => {
                const result = await library.maxSwap(
                    test.base,
                    test.quote,
                    test.isBaseToQuote,
                    test.isExactInput,
                    test.feeRatio,
                    test.priceBoundX96,
                )
                expect(result).to.eq(test.expected)
            })
        })
    })
})
