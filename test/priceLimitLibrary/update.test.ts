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

    describe("update", async () => {
        ;[
            {
                title: "initial",
                referencePrice: 0,
                referenceBlockNumber: 0,
                price: 100,
                afterReferencePrice: 100,
                afterReferenceBlockNumber: 1,
            },
            {
                title: "next",
                referencePrice: 1,
                referenceBlockNumber: 0,
                price: 2,
                afterReferencePrice: 2,
                afterReferenceBlockNumber: 1,
            },
            {
                title: "same",
                referencePrice: 1,
                referenceBlockNumber: 1,
                price: 2,
                afterReferencePrice: 1,
                afterReferenceBlockNumber: 1,
            },
            {
                title: "before",
                referencePrice: 1,
                referenceBlockNumber: 2,
                price: 2,
                afterReferencePrice: 1,
                afterReferenceBlockNumber: 2,
            },
        ].forEach(test => {
            it(test.title, async () => {
                const blockNum = await hre.ethers.provider.getBlockNumber()

                await library.update(
                    {
                        referencePrice: test.referencePrice,
                        referenceBlockNumber: blockNum + test.referenceBlockNumber,
                    },
                    test.price,
                )

                const res = await library.priceLimitInfo()
                expect(res.referencePrice).to.eq(test.afterReferencePrice)
                expect(res.referenceBlockNumber).to.eq(blockNum + test.afterReferenceBlockNumber)
            })
        })
    })
})
