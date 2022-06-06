import { expect } from "chai"
import { waffle } from "hardhat"
import { TestTakerLibrary } from "../../typechain"
import { createTakerLibraryFixture } from "./fixtures"
import { BigNumberish } from "ethers"
import { MockContract } from "ethereum-waffle"

describe("TakerLibrary addToTakerBalance", () => {
    let loadFixture = waffle.createFixtureLoader(waffle.provider.getWallets())
    let fixture

    let library: TestTakerLibrary
    let market: MockContract

    beforeEach(async () => {
        fixture = await loadFixture(createTakerLibraryFixture())
        library = fixture.takerLibrary
        market = fixture.market
    })

    describe("empty markets", async () => {
        it("registered", async () => {
            await expect(library.addToTakerBalance(market.address, 1, -1, 0, 1))
                .to.emit(library, "AddToTakerBalanceResult")
                .withArgs(0)
            const markets = await library.getAccountMarkets()
            expect(markets.length).to.eq(1)
            expect(markets[0]).to.eq(market.address)
        })

        it("revert when maxMarketsPerAccount is zero", async () => {
            await expect(library.addToTakerBalance(market.address, 1, -1, 0, 0)).to.revertedWith(
                "AL_UP: too many markets",
            )
        })
    })

    describe("addToTakerBalance", async () => {
        ;[
            {
                title: "long",
                collateralBalance: 0,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                baseShare: 1,
                quoteBalance: -1,
                quoteFee: 0,
                realizedPnl: 0,
                revertedWith: void 0,
            },
            {
                title: "short",
                collateralBalance: 0,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                baseShare: -1,
                quoteBalance: 1,
                quoteFee: 0,
                realizedPnl: 0,
                revertedWith: void 0,
            },
            {
                title: "close long all",
                collateralBalance: 1,
                takerInfo: {
                    baseBalanceShare: 10,
                    quoteBalance: -3,
                },
                baseShare: -10,
                quoteBalance: 15,
                quoteFee: 0,
                realizedPnl: 12,
                revertedWith: void 0,
            },
            {
                title: "close short all",
                collateralBalance: 1,
                takerInfo: {
                    baseBalanceShare: -10,
                    quoteBalance: 3,
                },
                baseShare: 10,
                quoteBalance: -15,
                quoteFee: 0,
                realizedPnl: -12,
                revertedWith: void 0,
            },
            {
                title: "close long partial",
                collateralBalance: 1,
                takerInfo: {
                    baseBalanceShare: 100,
                    quoteBalance: -10,
                },
                baseShare: -30,
                quoteBalance: 15,
                quoteFee: 0,
                realizedPnl: 12,
                revertedWith: void 0,
            },
            {
                title: "close short partial",
                collateralBalance: 1,
                takerInfo: {
                    baseBalanceShare: -100,
                    quoteBalance: 10,
                },
                baseShare: 30,
                quoteBalance: -15,
                quoteFee: 0,
                realizedPnl: -12,
                revertedWith: void 0,
            },
            {
                title: "flip long",
                collateralBalance: 1,
                takerInfo: {
                    baseBalanceShare: 100,
                    quoteBalance: -100,
                },
                baseShare: -140,
                quoteBalance: 14,
                quoteFee: 0,
                realizedPnl: -90,
                revertedWith: void 0,
            },
            {
                title: "flip short",
                collateralBalance: 1,
                takerInfo: {
                    baseBalanceShare: -100,
                    quoteBalance: 100,
                },
                baseShare: 140,
                quoteBalance: -14,
                quoteFee: 0,
                realizedPnl: 90,
                revertedWith: void 0,
            },
            {
                title: "fee",
                collateralBalance: 1,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                baseShare: 1,
                quoteBalance: -1,
                quoteFee: 10,
                realizedPnl: 10,
                revertedWith: void 0,
            },
            {
                title: "invalid 1",
                collateralBalance: 0,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                baseShare: 1,
                quoteBalance: 1,
                quoteFee: 0,
                revertedWith: "TL_ATTB: invalid input",
            },
            {
                title: "invalid 2",
                collateralBalance: 0,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                baseShare: -1,
                quoteBalance: -1,
                quoteFee: 0,
                revertedWith: "TL_ATTB: invalid input",
            },
            {
                title: "invalid 3",
                collateralBalance: 0,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                baseShare: 1,
                quoteBalance: 0,
                quoteFee: 0,
                revertedWith: "TL_ATTB: invalid input",
            },
            {
                title: "invalid 4",
                collateralBalance: 0,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                baseShare: 0,
                quoteBalance: 1,
                quoteFee: 0,
                revertedWith: "TL_ATTB: invalid input",
            },
            {
                title: "zero",
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 100,
                    quoteBalance: -100,
                },
                baseShare: 0,
                quoteBalance: 0,
                quoteFee: 10,
                realizedPnl: 10,
                revertedWith: void 0,
            },
        ].forEach(test => {
            it(test.title, async () => {
                await library.setAccountInfo({ collateralBalance: test.collateralBalance }, [market.address])
                await library.setTakerInfo(market.address, test.takerInfo)

                const res = expect(
                    library.addToTakerBalance(market.address, test.baseShare, test.quoteBalance, test.quoteFee, 1),
                )

                if (test.revertedWith === void 0) {
                    await res.to.emit(library, "AddToTakerBalanceResult").withArgs(test.realizedPnl)

                    const vault = await library.accountInfo()
                    expect(vault.collateralBalance).to.eq(test.collateralBalance + test.realizedPnl)

                    const takerInfo = await library.getTakerInfo(market.address)
                    expect(takerInfo.baseBalanceShare).to.eq(test.takerInfo.baseBalanceShare + test.baseShare)
                    expect(takerInfo.quoteBalance).to.eq(
                        test.takerInfo.quoteBalance + test.quoteBalance + test.quoteFee - test.realizedPnl,
                    )

                    // constraints
                    expect(
                        (takerInfo.baseBalanceShare.eq(0) && takerInfo.quoteBalance.eq(0)) ||
                            takerInfo.baseBalanceShare.mul(takerInfo.quoteBalance).lt(0),
                    ).to.be.true
                } else {
                    await res.to.revertedWith(test.revertedWith)
                }
            })
        })
    })
})
