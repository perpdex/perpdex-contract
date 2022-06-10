// import { expect } from "chai"
// import { waffle } from "hardhat"
// import { TestPriceLimitLibrary } from "../../typechain"
// import { createPriceLimitLibraryFixture } from "./fixtures"
//
// describe("PriceLimitLibrary isWithinPriceLimit", () => {
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
//     describe("isWithinPriceLimit", () => {
//         ;[
//             {
//                 title: "within small",
//                 referencePrice: 100,
//                 price: 90,
//                 priceLimitRatio: 1e5,
//                 result: true,
//             },
//             {
//                 title: "within large",
//                 referencePrice: 100,
//                 price: 110,
//                 priceLimitRatio: 1e5,
//                 result: true,
//             },
//             {
//                 title: "too small",
//                 referencePrice: 100,
//                 price: 89,
//                 priceLimitRatio: 1e5,
//                 result: false,
//             },
//             {
//                 title: "too large",
//                 referencePrice: 100,
//                 price: 111,
//                 priceLimitRatio: 1e5,
//                 result: false,
//             },
//             {
//                 title: "zero reference price",
//                 referencePrice: 0,
//                 price: 100,
//                 priceLimitRatio: 1e5,
//                 result: false,
//             },
//             {
//                 title: "zero price out",
//                 referencePrice: 100,
//                 price: 0,
//                 priceLimitRatio: 1e5,
//                 result: false,
//             },
//             {
//                 title: "zero price in",
//                 referencePrice: 100,
//                 price: 0,
//                 priceLimitRatio: 1e6,
//                 result: true,
//             },
//         ].forEach(test => {
//             it(test.title, async () => {
//                 const res = await library.isWithinPriceLimit(test.referencePrice, test.price, test.priceLimitRatio)
//                 expect(res).to.eq(test.result)
//             })
//         })
//     })
// })
