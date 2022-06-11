import { expect } from "chai"
import { waffle } from "hardhat"
import { TestPriceLimitLibrary } from "../../typechain"
import { createPriceLimitLibraryFixture } from "./fixtures"
import { getTimestamp, setNextTimestamp } from "../helper/time"

describe("PriceLimitLibrary updateDry", () => {
    let loadFixture = waffle.createFixtureLoader(waffle.provider.getWallets())
    let fixture

    let library: TestPriceLimitLibrary

    beforeEach(async () => {
        fixture = await loadFixture(createPriceLimitLibraryFixture())
        library = fixture.priceLimitLibrary
    })

    describe("updateDry", () => {
        ;[
            {
                title: "before. not updating",
                emaSec: 0,
                referencePrice: 1,
                referenceTimestamp: 1,
                emaPrice: 2,
                price: 100,
                afterReferencePrice: 1,
                afterReferenceTimestamp: void 0,
                afterEmaPrice: 2,
            },
            {
                title: "same time. not updating",
                emaSec: 0,
                referencePrice: 1,
                referenceTimestamp: 0,
                emaPrice: 2,
                price: 100,
                afterReferencePrice: 1,
                afterReferenceTimestamp: void 0,
                afterEmaPrice: 2,
            },
            {
                title: "after. updating",
                emaSec: 0,
                referencePrice: 1,
                referenceTimestamp: -1,
                emaPrice: 2,
                price: 100,
                afterReferencePrice: 100,
                afterReferenceTimestamp: 0,
                afterEmaPrice: 100,
            },
            {
                title: "initialize emaPrice",
                emaSec: 60,
                referencePrice: 0,
                referenceTimestamp: -1,
                emaPrice: 0,
                price: 100,
                afterReferencePrice: 100,
                afterReferenceTimestamp: 0,
                afterEmaPrice: 100,
            },
            {
                title: "ema calculation",
                emaSec: 60,
                referencePrice: 100,
                referenceTimestamp: -20,
                emaPrice: 100,
                price: 200,
                afterReferencePrice: 200,
                afterReferenceTimestamp: 0,
                afterEmaPrice: 125,
            },
        ].forEach(test => {
            it(test.title, async () => {
                const nextTimestamp = (await getTimestamp()) + 1000

                await library.setPriceLimitConfig({
                    normalOrderRatio: 5e4,
                    liquidationRatio: 10e4,
                    emaNormalOrderRatio: 5e4,
                    emaLiquidationRatio: 10e4,
                    emaSec: test.emaSec,
                })

                await library.setPriceLimitInfo({
                    referencePrice: test.referencePrice,
                    referenceTimestamp: nextTimestamp + test.referenceTimestamp,
                    emaPrice: test.emaPrice,
                })

                await setNextTimestamp(nextTimestamp, true)

                const updated = await library.updateDry(test.price)
                expect(updated.referencePrice).to.eq(test.afterReferencePrice)
                expect(updated.referenceTimestamp).to.eq(
                    test.afterReferenceTimestamp === void 0 ? 0 : nextTimestamp + test.afterReferenceTimestamp,
                )
                expect(updated.emaPrice).to.eq(test.afterEmaPrice)
            })
        })
    })
})
