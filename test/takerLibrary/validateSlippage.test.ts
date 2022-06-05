import { expect } from "chai"
import { waffle } from "hardhat"
import { TestTakerLibrary } from "../../typechain"
import { createTakerLibraryFixture } from "./fixtures"
import { BigNumber, BigNumberish, Wallet } from "ethers"
import { MockContract } from "ethereum-waffle"

describe("TakerLibrary", () => {
    let loadFixture = waffle.createFixtureLoader(waffle.provider.getWallets())
    let fixture

    let library: TestTakerLibrary
    let priceFeedBase: MockContract
    let priceFeedQuote: MockContract

    beforeEach(async () => {
        fixture = await loadFixture(createTakerLibraryFixture())
        library = fixture.takerLibrary
    })

    // TODO:
    // describe("validateSlippage", async () => {
    //     ;[
    //         {
    //             title: "normal",
    //             isBaseToQuote: false,
    //             isExactInput: true,
    //             base: 100,
    //             quote: -100,
    //             uint256 oppositeAmountBound
    //         },
    //         {
    //             title: "base",
    //             base: 1,
    //             quote: 1,
    //             priceBase: BigNumber.from(10).pow(18),
    //             revertedWith: void 0,
    //         },
    //         {
    //             title: "quote",
    //             base: 1,
    //             quote: 1,
    //             priceQuote: BigNumber.from(10).pow(18),
    //             revertedWith: void 0,
    //         },
    //         {
    //             title: "invalid base price",
    //             base: 1,
    //             quote: 1,
    //             priceBase: 0,
    //             revertedWith: "FL_VILP: invalid base price",
    //         },
    //         {
    //             title: "invalid quote price",
    //             base: 1,
    //             quote: 1,
    //             priceQuote: 0,
    //             revertedWith: "FL_VILP: invalid quote price",
    //         },
    //         {
    //             title: "too high mark",
    //             base: 100,
    //             quote: 111,
    //             priceBase: BigNumber.from(10).pow(18),
    //             revertedWith: "FL_VILP: too far from index",
    //         },
    //         {
    //             title: "too low mark",
    //             base: 100,
    //             quote: 89,
    //             priceBase: BigNumber.from(10).pow(18),
    //             revertedWith: "FL_VILP: too far from index",
    //         },
    //         {
    //             title: "too high base",
    //             base: 1,
    //             quote: 1,
    //             priceBase: BigNumber.from(10).pow(18).mul(100).div(111),
    //             revertedWith: "FL_VILP: too far from index",
    //         },
    //         {
    //             title: "too low base",
    //             base: 1,
    //             quote: 1,
    //             priceBase: BigNumber.from(10).pow(18).mul(100).div(89),
    //             revertedWith: "FL_VILP: too far from index",
    //         },
    //         {
    //             title: "too high quote",
    //             base: 1,
    //             quote: 1,
    //             priceQuote: BigNumber.from(10).pow(18).mul(111).div(100),
    //             revertedWith: "FL_VILP: too far from index",
    //         },
    //         {
    //             title: "too low quote",
    //             base: 1,
    //             quote: 1,
    //             priceQuote: BigNumber.from(10).pow(18).mul(89).div(100),
    //             revertedWith: "FL_VILP: too far from index",
    //         },
    //     ].forEach(test => {
    //         it(test.title, async () => {
    //             const pfBase = test.priceBase !== void 0 ? priceFeedBase.address : hre.ethers.constants.AddressZero
    //             const pfQuote = test.priceQuote !== void 0 ? priceFeedQuote.address : hre.ethers.constants.AddressZero
    //
    //             if (test.priceBase !== void 0) {
    //                 await priceFeedBase.mock.getPrice.returns(test.priceBase)
    //             }
    //             if (test.priceQuote !== void 0) {
    //                 await priceFeedQuote.mock.getPrice.returns(test.priceQuote)
    //             }
    //
    //             const res = expect(fundingLibrary.validateInitialLiquidityPrice(pfBase, pfQuote, test.base, test.quote))
    //
    //             if (test.revertedWith !== void 0) {
    //                 await res.to.revertedWith(test.revertedWith)
    //             } else {
    //                 await res.not.to.reverted
    //             }
    //         })
    //     })
    // })
})
