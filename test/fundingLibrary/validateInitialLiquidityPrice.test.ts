import { expect } from "chai"
import { waffle } from "hardhat"
import { TestFundingLibrary } from "../../typechain"
import { createFundingLibraryFixture } from "./fixtures"
import { BigNumber, BigNumberish, Wallet } from "ethers"
import { MockContract } from "ethereum-waffle"

describe("FundingLibrary", () => {
    let loadFixture = waffle.createFixtureLoader(waffle.provider.getWallets())
    let fixture

    let fundingLibrary: TestFundingLibrary
    let priceFeedBase: MockContract
    let priceFeedQuote: MockContract

    beforeEach(async () => {
        fixture = await loadFixture(createFundingLibraryFixture())
        fundingLibrary = fixture.fundingLibrary
        priceFeedBase = fixture.priceFeedBase
        priceFeedQuote = fixture.priceFeedQuote
    })

    describe("validateInitialLiquidityPrice", () => {
        ;[
            {
                title: "normal",
                base: 1,
                quote: 1,
                priceBase: BigNumber.from(10).pow(18),
                priceQuote: BigNumber.from(10).pow(18),
                revertedWith: void 0,
            },
            {
                title: "base",
                base: 1,
                quote: 1,
                priceBase: BigNumber.from(10).pow(18),
                revertedWith: void 0,
            },
            {
                title: "quote",
                base: 1,
                quote: 1,
                priceQuote: BigNumber.from(10).pow(18),
                revertedWith: void 0,
            },
            {
                title: "invalid base price",
                base: 1,
                quote: 1,
                priceBase: 0,
                revertedWith: "FL_VILP: invalid base price",
            },
            {
                title: "invalid quote price",
                base: 1,
                quote: 1,
                priceQuote: 0,
                revertedWith: "FL_VILP: invalid quote price",
            },
            {
                title: "getPrice revert base",
                base: 1,
                quote: 1,
                priceBase: "revert",
                revertedWith: "FL_VILP: invalid base price",
            },
            {
                title: "getPrice revert quote",
                base: 1,
                quote: 1,
                priceQuote: "revert",
                revertedWith: "FL_VILP: invalid quote price",
            },
            {
                title: "decimals overflow base",
                base: 1,
                quote: 1,
                priceBase: 1,
                decimalsBase: 78,
                revertedWith: "FL_VILP: invalid base decimals",
            },
            {
                title: "decimals overflow quote",
                base: 1,
                quote: 1,
                priceQuote: 1,
                decimalsQuote: 78,
                revertedWith: "FL_VILP: invalid quote decimals",
            },
            {
                title: "decimals revert base",
                base: 1,
                quote: 1,
                priceBase: 1,
                decimalsBase: "revert",
                revertedWith: "FL_VILP: invalid base decimals",
            },
            {
                title: "decimals revert quote",
                base: 1,
                quote: 1,
                priceQuote: 1,
                decimalsQuote: "revert",
                revertedWith: "FL_VILP: invalid quote decimals",
            },
            {
                title: "too high mark",
                base: 100,
                quote: 111,
                priceBase: BigNumber.from(10).pow(18),
                revertedWith: "FL_VILP: too far from index",
            },
            {
                title: "too low mark",
                base: 100,
                quote: 89,
                priceBase: BigNumber.from(10).pow(18),
                revertedWith: "FL_VILP: too far from index",
            },
            {
                title: "too high base",
                base: 1,
                quote: 1,
                priceBase: BigNumber.from(10).pow(18).mul(100).div(111),
                revertedWith: "FL_VILP: too far from index",
            },
            {
                title: "too low base",
                base: 1,
                quote: 1,
                priceBase: BigNumber.from(10).pow(18).mul(100).div(89),
                revertedWith: "FL_VILP: too far from index",
            },
            {
                title: "too high quote",
                base: 1,
                quote: 1,
                priceQuote: BigNumber.from(10).pow(18).mul(111).div(100),
                revertedWith: "FL_VILP: too far from index",
            },
            {
                title: "too low quote",
                base: 1,
                quote: 1,
                priceQuote: BigNumber.from(10).pow(18).mul(89).div(100),
                revertedWith: "FL_VILP: too far from index",
            },
        ].forEach(test => {
            it(test.title, async () => {
                const pfBase = test.priceBase !== void 0 ? priceFeedBase.address : hre.ethers.constants.AddressZero
                const pfQuote = test.priceQuote !== void 0 ? priceFeedQuote.address : hre.ethers.constants.AddressZero

                if (test.priceBase === "revert") {
                    await priceFeedBase.mock.getPrice.revertsWithReason("TEST: invalid base price")
                } else if (test.priceBase !== void 0) {
                    await priceFeedBase.mock.getPrice.returns(test.priceBase)
                }
                if (test.priceQuote === "revert") {
                    await priceFeedQuote.mock.getPrice.revertsWithReason("TEST: invalid quote price")
                } else if (test.priceQuote !== void 0) {
                    await priceFeedQuote.mock.getPrice.returns(test.priceQuote)
                }

                if (test.decimalsBase === "revert") {
                    await priceFeedBase.mock.decimals.revertsWithReason("TEST: invalid base decimals")
                } else if (test.decimalsBase !== void 0) {
                    await priceFeedBase.mock.decimals.returns(test.decimalsBase)
                }
                if (test.decimalsQuote === "revert") {
                    await priceFeedQuote.mock.decimals.revertsWithReason("TEST: invalid quote decimals")
                } else if (test.decimalsQuote !== void 0) {
                    await priceFeedQuote.mock.decimals.returns(test.decimalsQuote)
                }

                const res = expect(fundingLibrary.validateInitialLiquidityPrice(pfBase, pfQuote, test.base, test.quote))

                if (test.revertedWith !== void 0) {
                    await res.to.revertedWith(test.revertedWith)
                } else {
                    await res.not.to.reverted
                }
            })
        })
    })
})
