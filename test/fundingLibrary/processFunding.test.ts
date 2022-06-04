import { expect } from "chai"
import { waffle } from "hardhat"
import { TestFundingLibrary } from "../../typechain"
import { createFundingLibraryFixture } from "./fixtures"
import { BigNumber, BigNumberish, Wallet } from "ethers"
import { MockContract } from "ethereum-waffle"

describe("FundingLibrary processFunding", () => {
    let loadFixture = waffle.createFixtureLoader(waffle.provider.getWallets())
    let fixture

    let fundingLibrary: TestFundingLibrary
    let priceFeedBase: MockContract
    let priceFeedQuote: MockContract

    let getTimestamp = async () => {
        const blockNum = await hre.ethers.provider.getBlockNumber()
        const block = await hre.ethers.provider.getBlock(blockNum)
        return block.timestamp
    }

    let setNextTimestamp = async value => {
        await hre.ethers.provider.send("evm_setNextBlockTimestamp", [value])
    }

    beforeEach(async () => {
        fixture = await loadFixture(createFundingLibraryFixture())
        fundingLibrary = fixture.fundingLibrary
        priceFeedBase = fixture.priceFeedBase
        priceFeedQuote = fixture.priceFeedQuote
    })

    describe("update condition", async () => {
        ;[
            {
                title: "initial",
                prevIndexPriceBase: 0,
                prevIndexPriceQuote: 0,
                prevIndexPriceTimestamp: -1,
                priceBase: 1,
                priceQuote: 1,
                updated: true,
            },
            {
                title: "base updated",
                prevIndexPriceBase: 2,
                prevIndexPriceQuote: 3,
                prevIndexPriceTimestamp: -1,
                priceBase: 4,
                priceQuote: 3,
                updated: true,
            },
            {
                title: "quote updated",
                prevIndexPriceBase: 2,
                prevIndexPriceQuote: 3,
                prevIndexPriceTimestamp: -1,
                priceBase: 2,
                priceQuote: 4,
                updated: true,
            },
            {
                title: "both updated",
                prevIndexPriceBase: 2,
                prevIndexPriceQuote: 3,
                prevIndexPriceTimestamp: -1,
                priceBase: 4,
                priceQuote: 5,
                updated: true,
            },
            {
                title: "same time",
                prevIndexPriceBase: 0,
                prevIndexPriceQuote: 0,
                prevIndexPriceTimestamp: 0,
                priceBase: 1,
                priceQuote: 1,
                updated: false,
            },
            {
                title: "same price both",
                prevIndexPriceBase: 2,
                prevIndexPriceQuote: 3,
                prevIndexPriceTimestamp: -1,
                priceBase: 2,
                priceQuote: 3,
                updated: false,
            },
            {
                title: "same price base",
                prevIndexPriceBase: 2,
                prevIndexPriceQuote: 1,
                prevIndexPriceTimestamp: -1,
                priceBase: 2,
                updated: false,
            },
            {
                title: "same price quote",
                prevIndexPriceBase: 1,
                prevIndexPriceQuote: 3,
                prevIndexPriceTimestamp: -1,
                priceQuote: 3,
                updated: false,
            },
            {
                title: "invalid price base",
                prevIndexPriceBase: 2,
                prevIndexPriceQuote: 1,
                prevIndexPriceTimestamp: -1,
                priceBase: 0,
                updated: false,
            },
            {
                title: "invalid price quote",
                prevIndexPriceBase: 1,
                prevIndexPriceQuote: 3,
                prevIndexPriceTimestamp: -1,
                priceQuote: 0,
                updated: false,
            },
            {
                title: "invalid price both",
                prevIndexPriceBase: 2,
                prevIndexPriceQuote: 3,
                prevIndexPriceTimestamp: -1,
                priceBase: 0,
                priceQuote: 0,
                updated: false,
            },
        ].forEach(test => {
            it(test.title, async () => {
                const currentTimestamp = await getTimestamp()

                await fundingLibrary.setFundingInfo({
                    prevIndexPriceBase: test.prevIndexPriceBase,
                    prevIndexPriceQuote: test.prevIndexPriceQuote,
                    prevIndexPriceTimestamp: currentTimestamp + 1000 + test.prevIndexPriceTimestamp,
                })
                if (test.priceBase !== void 0) {
                    await priceFeedBase.mock.getPrice.returns(test.priceBase)
                }
                if (test.priceQuote !== void 0) {
                    await priceFeedQuote.mock.getPrice.returns(test.priceQuote)
                }

                await setNextTimestamp(currentTimestamp + 1000)

                await expect(
                    fundingLibrary.processFunding({
                        priceFeedBase:
                            test.priceBase !== void 0 ? priceFeedBase.address : hre.ethers.constants.AddressZero,
                        priceFeedQuote:
                            test.priceQuote !== void 0 ? priceFeedQuote.address : hre.ethers.constants.AddressZero,
                        markPriceX96: 1,
                        maxElapsedSec: 1,
                        maxPremiumRatio: 0,
                        rolloverSec: 1,
                    }),
                ).to.emit(fundingLibrary, "ProcessFundingResult")

                const res = await fundingLibrary.fundingInfo()
                if (test.updated) {
                    expect(res.prevIndexPriceBase).to.eq(test.priceBase !== void 0 ? test.priceBase : 1)
                    expect(res.prevIndexPriceQuote).to.eq(test.priceQuote !== void 0 ? test.priceQuote : 1)
                    expect(res.prevIndexPriceTimestamp).to.eq(currentTimestamp + 1000)
                } else {
                    expect(res.prevIndexPriceBase).to.eq(test.prevIndexPriceBase)
                    expect(res.prevIndexPriceQuote).to.eq(test.prevIndexPriceQuote)
                    expect(res.prevIndexPriceTimestamp).to.eq(currentTimestamp + 1000 + test.prevIndexPriceTimestamp)
                }
            })
        })
    })

    describe("funding rate calculation", async () => {
        ;[
            {
                title: "neutral both",
                elapsedTime: 1,
                priceBase: BigNumber.from(10).pow(18),
                priceQuote: BigNumber.from(10).pow(18),
                markPriceX96: BigNumber.from(2).pow(96),
                maxElapsedSec: 1,
                maxPremiumRatio: 1,
                rolloverSec: 1,
                fundingRateX96: 0,
            },
            {
                title: "positive base",
                elapsedTime: 1,
                priceBase: BigNumber.from(10).pow(18).mul(4).div(5),
                markPriceX96: BigNumber.from(2).pow(96),
                maxElapsedSec: 1,
                maxPremiumRatio: 1e6,
                rolloverSec: 1,
                fundingRateX96: BigNumber.from(2).pow(96).div(4),
            },
            {
                title: "positive quote",
                elapsedTime: 1,
                priceQuote: BigNumber.from(10).pow(18).mul(5).div(4),
                markPriceX96: BigNumber.from(2).pow(96),
                maxElapsedSec: 1,
                maxPremiumRatio: 1e6,
                rolloverSec: 1,
                fundingRateX96: BigNumber.from(2).pow(96).div(4),
            },
            {
                title: "negative base",
                elapsedTime: 1,
                priceBase: BigNumber.from(10).pow(18).mul(5).div(4),
                markPriceX96: BigNumber.from(2).pow(96),
                maxElapsedSec: 1,
                maxPremiumRatio: 1e6,
                rolloverSec: 1,
                fundingRateX96: BigNumber.from(2).pow(96).div(-5).sub(1), // rounding error
            },
            {
                title: "negative quote",
                elapsedTime: 1,
                priceQuote: BigNumber.from(10).pow(18).mul(3).div(4),
                markPriceX96: BigNumber.from(2).pow(96),
                maxElapsedSec: 1,
                maxPremiumRatio: 1e6,
                rolloverSec: 1,
                fundingRateX96: BigNumber.from(2).pow(96).div(-4),
            },
            {
                title: "positive mark both",
                elapsedTime: 1,
                priceBase: BigNumber.from(10).pow(18),
                priceQuote: BigNumber.from(10).pow(18),
                markPriceX96: BigNumber.from(2).pow(96).mul(5).div(4),
                maxElapsedSec: 1,
                maxPremiumRatio: 1e6,
                rolloverSec: 1,
                fundingRateX96: BigNumber.from(2).pow(96).div(4),
            },
            {
                title: "positive mark base",
                elapsedTime: 1,
                priceBase: BigNumber.from(10).pow(18),
                markPriceX96: BigNumber.from(2).pow(96).mul(5).div(4),
                maxElapsedSec: 1,
                maxPremiumRatio: 1e6,
                rolloverSec: 1,
                fundingRateX96: BigNumber.from(2).pow(96).div(4),
            },
            {
                title: "positive mark quote",
                elapsedTime: 1,
                priceQuote: BigNumber.from(10).pow(18),
                markPriceX96: BigNumber.from(2).pow(96).mul(5).div(4),
                maxElapsedSec: 1,
                maxPremiumRatio: 1e6,
                rolloverSec: 1,
                fundingRateX96: BigNumber.from(2).pow(96).div(4),
            },
            {
                title: "positive rolloverSec",
                elapsedTime: 1,
                priceBase: BigNumber.from(10).pow(18),
                markPriceX96: BigNumber.from(2).pow(96).mul(5).div(4),
                maxElapsedSec: 1,
                maxPremiumRatio: 1e6,
                rolloverSec: 2,
                fundingRateX96: BigNumber.from(2).pow(96).div(4).div(2),
            },
            {
                title: "positive elapsedTime",
                elapsedTime: 2,
                priceBase: BigNumber.from(10).pow(18),
                markPriceX96: BigNumber.from(2).pow(96).mul(5).div(4),
                maxElapsedSec: 2,
                maxPremiumRatio: 1e6,
                rolloverSec: 1,
                fundingRateX96: BigNumber.from(2).pow(96).div(4).mul(2),
            },
            {
                title: "positive maxElapsedTime",
                elapsedTime: 2,
                priceBase: BigNumber.from(10).pow(18),
                markPriceX96: BigNumber.from(2).pow(96).mul(5).div(4),
                maxElapsedSec: 1,
                maxPremiumRatio: 1e6,
                rolloverSec: 1,
                fundingRateX96: BigNumber.from(2).pow(96).div(4).mul(1),
            },
            {
                title: "positive maxPremiumRatio",
                elapsedTime: 1,
                priceBase: BigNumber.from(10).pow(18),
                markPriceX96: BigNumber.from(2).pow(96).mul(5).div(4),
                maxElapsedSec: 1,
                maxPremiumRatio: 125e3,
                rolloverSec: 1,
                fundingRateX96: BigNumber.from(2).pow(96).div(8),
            },
            {
                title: "positive maxPremiumRatio and rolloverSec",
                elapsedTime: 1,
                priceBase: BigNumber.from(10).pow(18),
                markPriceX96: BigNumber.from(2).pow(96).mul(5).div(4),
                maxElapsedSec: 1,
                maxPremiumRatio: 125e3,
                rolloverSec: 2,
                fundingRateX96: BigNumber.from(2).pow(96).div(16),
            },
            {
                title: "positive maxPremiumRatio and elapsedTime",
                elapsedTime: 2,
                priceBase: BigNumber.from(10).pow(18),
                markPriceX96: BigNumber.from(2).pow(96).mul(5).div(4),
                maxElapsedSec: 2,
                maxPremiumRatio: 125e3,
                rolloverSec: 1,
                fundingRateX96: BigNumber.from(2).pow(96).div(4),
            },
            {
                title: "positive premium too large",
                elapsedTime: 1,
                priceBase: 1,
                markPriceX96: BigNumber.from(2).pow(96),
                maxElapsedSec: 1,
                maxPremiumRatio: 125e3,
                rolloverSec: 1,
                fundingRateX96: BigNumber.from(2).pow(96).div(8),
            },
            {
                title: "negative premium too large",
                elapsedTime: 1,
                priceQuote: 1,
                markPriceX96: BigNumber.from(2).pow(96),
                maxElapsedSec: 1,
                maxPremiumRatio: 125e3,
                rolloverSec: 1,
                fundingRateX96: BigNumber.from(2).pow(96).div(-8),
            },
        ].forEach(test => {
            it(test.title, async () => {
                const currentTimestamp = await getTimestamp()

                await fundingLibrary.setFundingInfo({
                    prevIndexPriceBase: 0,
                    prevIndexPriceQuote: 0,
                    prevIndexPriceTimestamp: currentTimestamp + 1000 - test.elapsedTime,
                })
                if (test.priceBase !== void 0) {
                    await priceFeedBase.mock.getPrice.returns(test.priceBase)
                }
                if (test.priceQuote !== void 0) {
                    await priceFeedQuote.mock.getPrice.returns(test.priceQuote)
                }

                await setNextTimestamp(currentTimestamp + 1000)

                await expect(
                    fundingLibrary.processFunding({
                        priceFeedBase:
                            test.priceBase !== void 0 ? priceFeedBase.address : hre.ethers.constants.AddressZero,
                        priceFeedQuote:
                            test.priceQuote !== void 0 ? priceFeedQuote.address : hre.ethers.constants.AddressZero,
                        markPriceX96: test.markPriceX96,
                        maxElapsedSec: test.maxElapsedSec,
                        maxPremiumRatio: test.maxPremiumRatio,
                        rolloverSec: test.rolloverSec,
                    }),
                )
                    .to.emit(fundingLibrary, "ProcessFundingResult")
                    .withArgs(test.fundingRateX96)
            })
        })
    })
})
