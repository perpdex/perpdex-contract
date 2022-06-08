import { expect } from "chai"
import { waffle } from "hardhat"
import { TestPerpdexExchange, TestPerpdexMarket } from "../../typechain"
import { createPerpdexExchangeFixture } from "./fixtures"
import { BigNumber, Wallet } from "ethers"

describe("PerpdexExchange openPosition", () => {
    let loadFixture = waffle.createFixtureLoader(waffle.provider.getWallets())
    let fixture

    let exchange: TestPerpdexExchange
    let market: TestPerpdexMarket
    let owner: Wallet
    let alice: Wallet
    let bob: Wallet

    const Q96 = BigNumber.from(2).pow(96)
    const deadline = Q96

    beforeEach(async () => {
        fixture = await loadFixture(createPerpdexExchangeFixture())
        exchange = fixture.perpdexExchange
        market = fixture.perpdexMarket
        owner = fixture.owner
        alice = fixture.alice
        bob = fixture.bob

        await exchange.connect(owner).setImRatio(10e4)
        await exchange.connect(owner).setMmRatio(5e4)
        await exchange.connect(owner).setLiquidationRewardRatio(25e4)

        await market.connect(owner).setPoolFeeRatio(0)
        await market.connect(owner).setFundingMaxPremiumRatio(0)
        await exchange.connect(owner).setIsMarketAllowed(market.address, true)
        await market.connect(owner).setPriceLimitConfig({
            normalOrderRatio: 5e4,
            liquidationRatio: 10e4,
            emaNormalOrderRatio: 5e4,
            emaLiquidationRatio: 10e4,
            emaSec: 300,
        })

        await exchange.setInsuranceFundInfo({ balance: 10000 })
        await exchange.setProtocolInfo({ protocolFee: 10000 })

        await exchange.setAccountInfo(
            owner.address,
            {
                collateralBalance: 100000,
            },
            [],
        )

        await exchange.connect(owner).addLiquidity({
            market: market.address,
            base: 10000,
            quote: 10000,
            minBase: 0,
            minQuote: 0,
            deadline: deadline,
        })
    })

    describe("too many market", () => {
        it("max markets condition", async () => {})

        it("check gas fee", async () => {})
    })

    describe("various cases", () => {
        ;[
            {
                title: "long",
                isBaseToQuote: false,
                isExactInput: true,
                amount: 100,
                oppositeAmountBound: 0,
                protocolFeeRatio: 0,
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                outputBase: 99,
                outputQuote: -100,
                afterCollateralBalance: 100,
                afterTakerInfo: {
                    baseBalanceShare: 99,
                    quoteBalance: -100,
                },
                protocolFee: 0,
                insuranceFund: 0,
            },
            {
                title: "short",
                isBaseToQuote: true,
                isExactInput: true,
                amount: 100,
                oppositeAmountBound: 0,
                protocolFeeRatio: 0,
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                outputBase: -100,
                outputQuote: 99,
                afterCollateralBalance: 100,
                afterTakerInfo: {
                    baseBalanceShare: -100,
                    quoteBalance: 99,
                },
                protocolFee: 0,
                insuranceFund: 0,
            },
            {
                title: "long exact output",
                isBaseToQuote: false,
                isExactInput: false,
                amount: 100,
                oppositeAmountBound: 102,
                protocolFeeRatio: 0,
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                outputBase: 100,
                outputQuote: -102,
                afterCollateralBalance: 100,
                afterTakerInfo: {
                    baseBalanceShare: 100,
                    quoteBalance: -102,
                },
                protocolFee: 0,
                insuranceFund: 0,
            },
            {
                title: "short exact output",
                isBaseToQuote: true,
                isExactInput: false,
                amount: 100,
                oppositeAmountBound: 102,
                protocolFeeRatio: 0,
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                outputBase: -102,
                outputQuote: 100,
                afterCollateralBalance: 100,
                afterTakerInfo: {
                    baseBalanceShare: -102,
                    quoteBalance: 100,
                },
                protocolFee: 0,
                insuranceFund: 0,
            },
            {
                title: "protocol fee long",
                isBaseToQuote: false,
                isExactInput: true,
                amount: 100,
                oppositeAmountBound: 0,
                protocolFeeRatio: 1e4,
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                outputBase: 98,
                outputQuote: -100,
                afterCollateralBalance: 100,
                afterTakerInfo: {
                    baseBalanceShare: 98,
                    quoteBalance: -100,
                },
                protocolFee: 1,
                insuranceFund: 0,
            },
            {
                title: "protocol fee short",
                isBaseToQuote: true,
                isExactInput: true,
                amount: 200,
                oppositeAmountBound: 0,
                protocolFeeRatio: 1e4,
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                outputBase: -200,
                outputQuote: 195,
                afterCollateralBalance: 100,
                afterTakerInfo: {
                    baseBalanceShare: -200,
                    quoteBalance: 195,
                },
                protocolFee: 1,
                insuranceFund: 0,
            },
            {
                title: "close long all",
                isBaseToQuote: true,
                isExactInput: true,
                amount: 100,
                oppositeAmountBound: 0,
                protocolFeeRatio: 0,
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 100,
                    quoteBalance: -50,
                },
                outputBase: -100,
                outputQuote: 99,
                afterCollateralBalance: 149,
                afterTakerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                protocolFee: 0,
                insuranceFund: 0,
            },
            {
                title: "close long partial",
                isBaseToQuote: true,
                isExactInput: true,
                amount: 40,
                oppositeAmountBound: 0,
                protocolFeeRatio: 0,
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 100,
                    quoteBalance: -50,
                },
                outputBase: -40,
                outputQuote: 39,
                afterCollateralBalance: 119,
                afterTakerInfo: {
                    baseBalanceShare: 60,
                    quoteBalance: -30,
                },
                protocolFee: 0,
                insuranceFund: 0,
            },
            {
                title: "flip long",
                isBaseToQuote: true,
                isExactInput: true,
                amount: 200,
                oppositeAmountBound: 0,
                protocolFeeRatio: 0,
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 100,
                    quoteBalance: -50,
                },
                outputBase: -200,
                outputQuote: 196,
                afterCollateralBalance: 148,
                afterTakerInfo: {
                    baseBalanceShare: -100,
                    quoteBalance: 98,
                },
                protocolFee: 0,
                insuranceFund: 0,
            },
            {
                title: "not liquidatable because enough mm",
                notSelf: true,
                isBaseToQuote: false,
                isExactInput: true,
                amount: 100,
                oppositeAmountBound: 0,
                protocolFeeRatio: 0,
                collateralBalance: 5,
                takerInfo: {
                    baseBalanceShare: 100,
                    quoteBalance: -100,
                },
                revertedWith: "TL_OP: enough mm",
                revertedWithDry: "TL_OPD: enough mm",
            },
            {
                title: "open is not allowed when liquidation",
                notSelf: true,
                isBaseToQuote: false,
                isExactInput: true,
                amount: 100,
                oppositeAmountBound: 0,
                protocolFeeRatio: 0,
                collateralBalance: 4,
                takerInfo: {
                    baseBalanceShare: 100,
                    quoteBalance: -100,
                },
                revertedWith: "TL_OP: no open when liquidation",
                afterCollateralBalance: 4,
                afterTakerInfo: {
                    baseBalanceShare: 199,
                    quoteBalance: -200,
                },
            },
            {
                title: "open is not allowed when market closed",
                isMarketAllowed: false,
                isBaseToQuote: false,
                isExactInput: true,
                amount: 100,
                oppositeAmountBound: 0,
                protocolFeeRatio: 0,
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                revertedWith: "PE_CMA: market not allowed",
                revertedWithDry: "PE_CMA: market not allowed",
            },
            {
                title: "flip is not allowed when market closed",
                isMarketAllowed: false,
                isBaseToQuote: true,
                isExactInput: true,
                amount: 200,
                oppositeAmountBound: 0,
                protocolFeeRatio: 0,
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 100,
                    quoteBalance: -50,
                },
                revertedWith: "PE_CMA: market not allowed",
                revertedWithDry: "PE_CMA: market not allowed",
            },
            {
                title: "close all is not allowed when market closed",
                isMarketAllowed: false,
                isBaseToQuote: true,
                isExactInput: true,
                amount: 100,
                oppositeAmountBound: 0,
                protocolFeeRatio: 0,
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 100,
                    quoteBalance: -50,
                },
                revertedWith: "PE_CMA: market not allowed",
                revertedWithDry: "PE_CMA: market not allowed",
            },
            {
                title: "close partial is not allowed when market closed",
                isMarketAllowed: false,
                isBaseToQuote: true,
                isExactInput: true,
                amount: 40,
                oppositeAmountBound: 0,
                protocolFeeRatio: 0,
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 100,
                    quoteBalance: -50,
                },
                revertedWith: "PE_CMA: market not allowed",
                revertedWithDry: "PE_CMA: market not allowed",
            },
            {
                title: "not enough im",
                isBaseToQuote: false,
                isExactInput: true,
                amount: 100,
                oppositeAmountBound: 0,
                protocolFeeRatio: 0,
                collateralBalance: 5,
                takerInfo: {
                    baseBalanceShare: 100,
                    quoteBalance: -100,
                },
                revertedWith: "TL_OP: not enough im",
                afterCollateralBalance: 5,
                afterTakerInfo: {
                    baseBalanceShare: 199,
                    quoteBalance: -200,
                },
            },
            {
                title: "price limit normal order",
                isBaseToQuote: false,
                isExactInput: true,
                amount: 250,
                oppositeAmountBound: 0,
                protocolFeeRatio: 0,
                collateralBalance: 5,
                takerInfo: {
                    baseBalanceShare: 100,
                    quoteBalance: -100,
                },
                revertedWith: "PLL_C: price limit",
                revertedWithDry: "PLL_C: price limit",
            },
            {
                title: "price limit liquidation",
                notSelf: true,
                isBaseToQuote: false,
                isExactInput: true,
                amount: 500,
                oppositeAmountBound: 0,
                protocolFeeRatio: 0,
                collateralBalance: 40,
                takerInfo: {
                    baseBalanceShare: -1000,
                    quoteBalance: 1000,
                },
                revertedWith: "PLL_C: price limit",
                revertedWithDry: "PLL_C: price limit",
            },
            {
                title: "liquidation",
                notSelf: true,
                isBaseToQuote: true,
                isExactInput: true,
                amount: 100,
                oppositeAmountBound: 0,
                protocolFeeRatio: 0,
                collateralBalance: -49,
                takerInfo: {
                    baseBalanceShare: 100,
                    quoteBalance: -50,
                },
                outputBase: -100,
                outputQuote: 99,
                liquidation: true,
                liquidationReward: 1,
                afterCollateralBalance: 0 - 4,
                afterTakerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                protocolFee: 0,
                insuranceFund: 3,
            },
            {
                title: "liquidation self",
                notSelf: false,
                isBaseToQuote: true,
                isExactInput: true,
                amount: 100,
                oppositeAmountBound: 0,
                protocolFeeRatio: 0,
                collateralBalance: -49,
                takerInfo: {
                    baseBalanceShare: 100,
                    quoteBalance: -50,
                },
                outputBase: -100,
                outputQuote: 99,
                liquidation: true,
                liquidationReward: 1,
                afterCollateralBalance: 0 - 4 + 1,
                afterTakerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                protocolFee: 0,
                insuranceFund: 3,
            },
            {
                title: "long opposite amount condition",
                isBaseToQuote: false,
                isExactInput: true,
                amount: 100,
                oppositeAmountBound: 100,
                protocolFeeRatio: 0,
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                revertedWith: "TL_VS: too small opposite amount",
                revertedWithDry: "TL_VS: too small opposite amount",
            },
            {
                title: "long exact output opposite amount condition",
                isBaseToQuote: false,
                isExactInput: false,
                amount: 100,
                oppositeAmountBound: 101,
                protocolFeeRatio: 0,
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                revertedWith: "TL_VS: too large opposite amount",
                revertedWithDry: "TL_VS: too large opposite amount",
            },
        ].forEach(test => {
            describe(test.title, () => {
                beforeEach(async () => {
                    await exchange.connect(owner).setProtocolFeeRatio(test.protocolFeeRatio)

                    await exchange.setAccountInfo(
                        alice.address,
                        {
                            collateralBalance: test.collateralBalance,
                        },
                        [market.address],
                    )

                    await exchange.setTakerInfo(alice.address, market.address, test.takerInfo)

                    if (test.isMarketAllowed !== void 0) {
                        await exchange.connect(owner).setIsMarketAllowed(market.address, test.isMarketAllowed)
                    }
                })

                it("mutable", async () => {
                    const res = expect(
                        exchange.connect(test.notSelf ? bob : alice).openPosition({
                            trader: alice.address,
                            market: market.address,
                            isBaseToQuote: test.isBaseToQuote,
                            isExactInput: test.isExactInput,
                            amount: test.amount,
                            oppositeAmountBound: test.oppositeAmountBound,
                            deadline: deadline,
                        }),
                    )

                    if (test.revertedWith === void 0) {
                        const sharePrice = Q96.mul(10000 - test.outputQuote - test.protocolFee).div(
                            10000 - test.outputBase,
                        )

                        if (test.liquidation) {
                            await res.to
                                .emit(exchange, "PositionLiquidated")
                                .withArgs(
                                    alice.address,
                                    market.address,
                                    (test.notSelf ? bob : alice).address,
                                    test.outputBase,
                                    test.outputQuote,
                                    test.afterCollateralBalance -
                                        test.collateralBalance +
                                        test.insuranceFund +
                                        (test.notSelf ? test.liquidationReward : 0),
                                    test.protocolFee,
                                    Q96,
                                    sharePrice,
                                    test.liquidationReward,
                                    test.insuranceFund,
                                )
                        } else {
                            await res.to
                                .emit(exchange, "PositionChanged")
                                .withArgs(
                                    alice.address,
                                    market.address,
                                    test.outputBase,
                                    test.outputQuote,
                                    test.afterCollateralBalance - test.collateralBalance,
                                    test.protocolFee,
                                    Q96,
                                    sharePrice,
                                )
                        }

                        const accountInfo = await exchange.accountInfos(alice.address)
                        expect(accountInfo.collateralBalance).to.eq(test.afterCollateralBalance)

                        if (test.notSelf) {
                            const accountInfoBob = await exchange.accountInfos(bob.address)
                            expect(accountInfoBob.collateralBalance).to.eq(test.liquidationReward)
                        }

                        const takerInfo = await exchange.getTakerInfo(alice.address, market.address)
                        expect(takerInfo.baseBalanceShare).to.eq(test.afterTakerInfo.baseBalanceShare)
                        expect(takerInfo.quoteBalance).to.eq(test.afterTakerInfo.quoteBalance)

                        expect(await exchange.insuranceFundInfo()).to.eq(test.insuranceFund + 10000)
                        expect(await exchange.protocolInfo()).to.eq(test.protocolFee + 10000)
                    } else {
                        await res.to.revertedWith(test.revertedWith)
                    }
                })

                if (!test.liquidation) {
                    it("dry", async () => {
                        const call = exchange.previewOpenPosition({
                            trader: alice.address,
                            market: market.address,
                            caller: (test.notSelf ? bob : alice).address,
                            isBaseToQuote: test.isBaseToQuote,
                            isExactInput: test.isExactInput,
                            amount: test.amount,
                            oppositeAmountBound: test.oppositeAmountBound,
                        })

                        if (test.revertedWithDry === void 0) {
                            const resDry = await call
                            expect(resDry[0]).to.eq(
                                test.afterTakerInfo.baseBalanceShare - test.takerInfo.baseBalanceShare,
                            )
                            expect(resDry[1]).to.eq(
                                test.afterTakerInfo.quoteBalance -
                                    test.takerInfo.quoteBalance +
                                    test.afterCollateralBalance -
                                    test.collateralBalance,
                            )
                        } else {
                            await expect(call).to.revertedWith(test.revertedWithDry)
                        }
                    })
                }
            })
        })
    })
})
