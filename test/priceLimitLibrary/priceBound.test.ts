import { expect } from "chai"
import { waffle } from "hardhat"
import { TestPriceLimitLibrary } from "../../typechain"
import { createPriceLimitLibraryFixture } from "./fixtures"

describe("PriceLimitLibrary priceBound", () => {
    let loadFixture = waffle.createFixtureLoader(waffle.provider.getWallets())
    let fixture

    let library: TestPriceLimitLibrary

    beforeEach(async () => {
        fixture = await loadFixture(createPriceLimitLibraryFixture())
        library = fixture.priceLimitLibrary
    })

    describe("priceBound", () => {
        ;[
            {
                title: "lower reference normal",
                referencePrice: 100,
                emaPrice: 50,
                isLiquidation: false,
                isUpperBound: false,
                normalOrderRatio: 1e5,
                liquidationRatio: 2e5,
                emaNormalOrderRatio: 3e5,
                emaLiquidationRatio: 4e5,
                expected: 90,
            },
            {
                title: "lower reference liquidation",
                referencePrice: 100,
                emaPrice: 50,
                isLiquidation: true,
                isUpperBound: false,
                normalOrderRatio: 1e5,
                liquidationRatio: 2e5,
                emaNormalOrderRatio: 3e5,
                emaLiquidationRatio: 4e5,
                expected: 80,
            },
            {
                title: "lower ema normal",
                referencePrice: 50,
                emaPrice: 100,
                isLiquidation: false,
                isUpperBound: false,
                normalOrderRatio: 1e5,
                liquidationRatio: 2e5,
                emaNormalOrderRatio: 3e5,
                emaLiquidationRatio: 4e5,
                expected: 70,
            },
            {
                title: "lower ema liquidation",
                referencePrice: 50,
                emaPrice: 100,
                isLiquidation: true,
                isUpperBound: false,
                normalOrderRatio: 1e5,
                liquidationRatio: 2e5,
                emaNormalOrderRatio: 3e5,
                emaLiquidationRatio: 4e5,
                expected: 60,
            },
            {
                title: "upper reference normal",
                referencePrice: 100,
                emaPrice: 200,
                isLiquidation: false,
                isUpperBound: true,
                normalOrderRatio: 1e5,
                liquidationRatio: 2e5,
                emaNormalOrderRatio: 3e5,
                emaLiquidationRatio: 4e5,
                expected: 110,
            },
            {
                title: "upper reference liquidation",
                referencePrice: 100,
                emaPrice: 200,
                isLiquidation: true,
                isUpperBound: true,
                normalOrderRatio: 1e5,
                liquidationRatio: 2e5,
                emaNormalOrderRatio: 3e5,
                emaLiquidationRatio: 4e5,
                expected: 120,
            },
            {
                title: "upper ema normal",
                referencePrice: 200,
                emaPrice: 100,
                isLiquidation: false,
                isUpperBound: true,
                normalOrderRatio: 1e5,
                liquidationRatio: 2e5,
                emaNormalOrderRatio: 3e5,
                emaLiquidationRatio: 4e5,
                expected: 130,
            },
            {
                title: "upper ema liquidation",
                referencePrice: 200,
                emaPrice: 100,
                isLiquidation: true,
                isUpperBound: true,
                normalOrderRatio: 1e5,
                liquidationRatio: 2e5,
                emaNormalOrderRatio: 3e5,
                emaLiquidationRatio: 4e5,
                expected: 140,
            },
        ].forEach(test => {
            it(test.title, async () => {
                await library.setPriceLimitConfig({
                    normalOrderRatio: test.normalOrderRatio,
                    liquidationRatio: test.liquidationRatio,
                    emaNormalOrderRatio: test.emaNormalOrderRatio,
                    emaLiquidationRatio: test.emaLiquidationRatio,
                    emaSec: 0,
                })

                const result = await library.priceBound(
                    test.referencePrice,
                    test.emaPrice,
                    test.isLiquidation,
                    test.isUpperBound,
                )
                expect(result).to.eq(test.expected)
            })
        })
    })
})
