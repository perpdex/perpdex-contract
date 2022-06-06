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
        await exchange.connect(owner).setLiquidationRewardRatio(50e4)

        await market.connect(owner).setPoolFeeRatio(0)
        await market.connect(owner).setFundingMaxPremiumRatio(0)
        await exchange.connect(owner).setIsMarketAllowed(market.address, true)
        await exchange.connect(owner).setPriceLimitConfig({
            normalOrderRatio: 5e4,
            liquidationRatio: 10e4,
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
                revertedWith: "TL_OP: no open when closed",
                afterCollateralBalance: 100,
                afterTakerInfo: {
                    baseBalanceShare: 99,
                    quoteBalance: -100,
                },
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
                revertedWith: "TL_OP: no open when closed",
                afterCollateralBalance: 148,
                afterTakerInfo: {
                    baseBalanceShare: -100,
                    quoteBalance: 98,
                },
            },
            {
                title: "close all is allowed when market closed",
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
                afterCollateralBalance: 149,
                afterTakerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                protocolFee: 0,
                insuranceFund: 0,
            },
            {
                title: "close partial is allowed when market closed",
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
                afterCollateralBalance: 119,
                afterTakerInfo: {
                    baseBalanceShare: 60,
                    quoteBalance: -30,
                },
                protocolFee: 0,
                insuranceFund: 0,
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
                revertedWith: "TL_OP: normal order price limit",
                afterCollateralBalance: 5,
                afterTakerInfo: {
                    baseBalanceShare: 343,
                    quoteBalance: -350,
                },
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
                revertedWith: "TL_OP: liquidation price limit",
                afterCollateralBalance: 40,
                afterTakerInfo: {
                    baseBalanceShare: -524,
                    quoteBalance: 500,
                },
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
                liquidation: true,
                afterCollateralBalance: 0 - 4,
                afterTakerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                protocolFee: 0,
                insuranceFund: 2,
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
                        if (test.liquidation) {
                            await res.to.emit(exchange, "PositionLiquidated")
                        } else {
                            await res.to.emit(exchange, "PositionChanged")
                        }

                        const accountInfo = await exchange.accountInfos(alice.address)
                        expect(accountInfo.collateralBalance).to.eq(test.afterCollateralBalance)

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
                        const call = exchange.openPositionDry({
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
