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

        await market.connect(owner).setPoolFeeRatio(0)
        await market.connect(owner).setFundingMaxPremiumRatio(0)
        await exchange.connect(owner).setIsMarketAllowed(market.address, true)

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

    describe("openPosition", async () => {
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
        ].forEach(test => {
            it(test.title, async () => {
                await exchange.connect(owner).setProtocolFeeRatio(test.protocolFeeRatio)

                await exchange.setInsuranceFundInfo({ balance: 10000 })
                await exchange.setProtocolInfo({ protocolFee: 10000 })

                await exchange.setAccountInfo(
                    alice.address,
                    {
                        collateralBalance: test.collateralBalance,
                    },
                    [market.address],
                )

                await exchange.setTakerInfo(alice.address, market.address, test.takerInfo)

                const resDry = await exchange.connect(alice).openPositionDry(
                    {
                        market: market.address,
                        isBaseToQuote: test.isBaseToQuote,
                        isExactInput: test.isExactInput,
                        amount: test.amount,
                        oppositeAmountBound: test.oppositeAmountBound,
                    },
                    alice.address,
                )
                expect(resDry[0]).to.eq(test.afterTakerInfo.baseBalanceShare - test.takerInfo.baseBalanceShare)
                expect(resDry[1]).to.eq(
                    test.afterTakerInfo.quoteBalance -
                        test.takerInfo.quoteBalance +
                        test.afterCollateralBalance -
                        test.collateralBalance,
                )

                const res = expect(
                    exchange.connect(alice).openPosition({
                        market: market.address,
                        isBaseToQuote: test.isBaseToQuote,
                        isExactInput: test.isExactInput,
                        amount: test.amount,
                        oppositeAmountBound: test.oppositeAmountBound,
                        deadline: deadline,
                    }),
                )
                await res.to.emit(exchange, "PositionChanged")

                const accountInfo = await exchange.accountInfos(alice.address)
                expect(accountInfo.collateralBalance).to.eq(test.afterCollateralBalance)

                const takerInfo = await exchange.getTakerInfo(alice.address, market.address)
                expect(takerInfo.baseBalanceShare).to.eq(test.afterTakerInfo.baseBalanceShare)
                expect(takerInfo.quoteBalance).to.eq(test.afterTakerInfo.quoteBalance)

                expect(await exchange.insuranceFundInfo()).to.eq(test.insuranceFund + 10000)
                expect(await exchange.protocolInfo()).to.eq(test.protocolFee + 10000)
            })
        })
    })
})
