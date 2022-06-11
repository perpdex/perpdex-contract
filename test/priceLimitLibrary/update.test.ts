import { expect } from "chai"
import { waffle } from "hardhat"
import { TestPriceLimitLibrary } from "../../typechain"
import { createPriceLimitLibraryFixture } from "./fixtures"

describe("PriceLimitLibrary update", () => {
    let loadFixture = waffle.createFixtureLoader(waffle.provider.getWallets())
    let fixture

    let library: TestPriceLimitLibrary

    beforeEach(async () => {
        fixture = await loadFixture(createPriceLimitLibraryFixture())
        library = fixture.priceLimitLibrary
    })

    describe("reference time 0", () => {
        it("not update", async () => {
            await library.setPriceLimitInfo({
                referencePrice: 1,
                referenceTimestamp: 2,
                emaPrice: 3,
            })
            await library.update({
                referencePrice: 10,
                referenceTimestamp: 0,
                emaPrice: 30,
            })

            const updated = await library.priceLimitInfo()
            expect(updated.referencePrice).to.eq(1)
            expect(updated.referenceTimestamp).to.eq(2)
            expect(updated.emaPrice).to.eq(3)
        })
    })

    describe("reference time > 0", () => {
        it("update", async () => {
            await library.setPriceLimitInfo({
                referencePrice: 1,
                referenceTimestamp: 2,
                emaPrice: 3,
            })
            await library.update({
                referencePrice: 10,
                referenceTimestamp: 3,
                emaPrice: 30,
            })

            const updated = await library.priceLimitInfo()
            expect(updated.referencePrice).to.eq(10)
            expect(updated.referenceTimestamp).to.eq(3)
            expect(updated.emaPrice).to.eq(30)
        })
    })
})
