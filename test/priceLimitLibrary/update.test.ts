// import { expect } from "chai"
// import { waffle } from "hardhat"
// import { TestPriceLimitLibrary } from "../../typechain"
// import { createPriceLimitLibraryFixture } from "./fixtures"
// import { getTimestamp, setNextTimestamp } from "../helper/time"
//
// describe("PriceLimitLibrary update", () => {
//     let loadFixture = waffle.createFixtureLoader(waffle.provider.getWallets())
//     let fixture
//
//     let library: TestPriceLimitLibrary
//
//     beforeEach(async () => {
//         fixture = await loadFixture(createPriceLimitLibraryFixture())
//         library = fixture.priceLimitLibrary
//     })
//
//     describe("update", () => {
//         ;[
//             {
//                 title: "initial",
//                 referencePrice: 0,
//                 referenceTimestamp: 0,
//                 price: 100,
//                 afterReferencePrice: 100,
//                 afterReferenceTimestamp: 1,
//             },
//             {
//                 title: "next",
//                 referencePrice: 1,
//                 referenceTimestamp: -1,
//                 price: 2,
//                 afterReferencePrice: 2,
//                 afterReferenceTimestamp: 0,
//             },
//             {
//                 title: "same",
//                 referencePrice: 1,
//                 referenceTimestamp: 0,
//                 price: 2,
//                 afterReferencePrice: 1,
//                 afterReferenceTimestamp: 0,
//             },
//             {
//                 title: "before",
//                 referencePrice: 1,
//                 referenceTimestamp: 1,
//                 price: 2,
//                 afterReferencePrice: 1,
//                 afterReferenceTimestamp: 1,
//             },
//         ].forEach(test => {
//             it(test.title, async () => {
//                 const nextTimestamp = (await getTimestamp()) + 1000
//                 await setNextTimestamp(nextTimestamp)
//
//                 await library.update(
//                     {
//                         referencePrice: test.referencePrice,
//                         referenceTimestamp: nextTimestamp + test.referenceTimestamp,
//                         emaPrice: test.referencePrice,
//                     },
//                     0,
//                     test.price,
//                 )
//
//                 const res = await library.priceLimitInfo()
//                 expect(res.referencePrice).to.eq(test.afterReferencePrice)
//                 expect(res.referenceTimestamp).to.eq(nextTimestamp + test.afterReferenceTimestamp)
//             })
//         })
//     })
// })
