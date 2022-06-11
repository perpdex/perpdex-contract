import { expect } from "chai"
import { waffle } from "hardhat"
import { TestPerpdexExchange, TestPerpdexMarket } from "../../../typechain"
import { createPerpdexExchangeFixture } from "../fixtures"
import { BigNumber, Wallet } from "ethers"

describe("PerpdexExchange getters", () => {
    let loadFixture = waffle.createFixtureLoader(waffle.provider.getWallets())
    let fixture

    let exchange: TestPerpdexExchange
    let market: TestPerpdexMarket
    let owner: Wallet
    let alice: Wallet
    let markets: TestPerpdexMarket[]

    const Q96 = BigNumber.from(2).pow(96)

    beforeEach(async () => {
        fixture = await loadFixture(createPerpdexExchangeFixture())
        exchange = fixture.perpdexExchange
        market = fixture.perpdexMarket
        owner = fixture.owner
        alice = fixture.alice
        markets = fixture.perpdexMarkets.slice(0, 2)
    })

    describe("AccountLibrary getters two markets", () => {
        ;[
            {
                title: "empty pool, zero",
                collateralBalance: 0,
                takerInfos: [
                    {
                        baseBalanceShare: 0,
                        quoteBalance: 0,
                    },
                    {
                        baseBalanceShare: 0,
                        quoteBalance: 0,
                    },
                ],
                makerInfos: [
                    {
                        liquidity: 0,
                        cumBaseSharePerLiquidityX96: 0,
                        cumQuotePerLiquidityX96: 0,
                    },
                    {
                        liquidity: 0,
                        cumBaseSharePerLiquidityX96: 0,
                        cumQuotePerLiquidityX96: 0,
                    },
                ],
                poolInfos: [
                    {
                        base: 0,
                        quote: 0,
                        totalLiquidity: 0,
                        cumBasePerLiquidityX96: 0,
                        cumQuotePerLiquidityX96: 0,
                        baseBalancePerShareX96: Q96,
                    },
                    {
                        base: 0,
                        quote: 0,
                        totalLiquidity: 0,
                        cumBasePerLiquidityX96: 0,
                        cumQuotePerLiquidityX96: 0,
                        baseBalancePerShareX96: Q96,
                    },
                ],
                totalAccountValue: 0,
                positionShares: [0, 0],
                positionNotionals: [0, 0],
                totalPositionNotional: 0,
                openPositionShares: [0, 0],
                openPositionNotionals: [0, 0],
                totalOpenPositionNotional: 0,
                hasEnoughMaintenanceMargin: true,
                hasEnoughInitialMargin: true,
            },
            {
                title: "long profit",
                collateralBalance: 100,
                takerInfos: [
                    {
                        baseBalanceShare: 25,
                        quoteBalance: -90,
                    },
                    {
                        baseBalanceShare: 30,
                        quoteBalance: -100,
                    },
                ],
                makerInfos: [
                    {
                        liquidity: 0,
                        cumBaseSharePerLiquidityX96: 0,
                        cumQuotePerLiquidityX96: 0,
                    },
                    {
                        liquidity: 0,
                        cumBaseSharePerLiquidityX96: 0,
                        cumQuotePerLiquidityX96: 0,
                    },
                ],
                poolInfos: [
                    {
                        base: 10000,
                        quote: 40000,
                        totalLiquidity: 20000,
                        cumBasePerLiquidityX96: 0,
                        cumQuotePerLiquidityX96: 0,
                        baseBalancePerShareX96: Q96,
                    },
                    {
                        base: 10000,
                        quote: 40000,
                        totalLiquidity: 20000,
                        cumBasePerLiquidityX96: 0,
                        cumQuotePerLiquidityX96: 0,
                        baseBalancePerShareX96: Q96,
                    },
                ],
                totalAccountValue: 130,
                positionShares: [25, 30],
                positionNotionals: [100, 120],
                totalPositionNotional: 220,
                openPositionShares: [25, 30],
                openPositionNotionals: [100, 120],
                totalOpenPositionNotional: 220,
                hasEnoughMaintenanceMargin: true,
                hasEnoughInitialMargin: true,
            },
            {
                title: "long profit and short loss",
                collateralBalance: 100,
                takerInfos: [
                    {
                        baseBalanceShare: 25,
                        quoteBalance: -90,
                    },
                    {
                        baseBalanceShare: -30,
                        quoteBalance: 100,
                    },
                ],
                makerInfos: [
                    {
                        liquidity: 0,
                        cumBaseSharePerLiquidityX96: 0,
                        cumQuotePerLiquidityX96: 0,
                    },
                    {
                        liquidity: 0,
                        cumBaseSharePerLiquidityX96: 0,
                        cumQuotePerLiquidityX96: 0,
                    },
                ],
                poolInfos: [
                    {
                        base: 10000,
                        quote: 40000,
                        totalLiquidity: 20000,
                        cumBasePerLiquidityX96: 0,
                        cumQuotePerLiquidityX96: 0,
                        baseBalancePerShareX96: Q96,
                    },
                    {
                        base: 10000,
                        quote: 40000,
                        totalLiquidity: 20000,
                        cumBasePerLiquidityX96: 0,
                        cumQuotePerLiquidityX96: 0,
                        baseBalancePerShareX96: Q96,
                    },
                ],
                totalAccountValue: 90,
                positionShares: [25, -30],
                positionNotionals: [100, -120],
                totalPositionNotional: 220,
                openPositionShares: [25, 30],
                openPositionNotionals: [100, 120],
                totalOpenPositionNotional: 220,
                hasEnoughMaintenanceMargin: true,
                hasEnoughInitialMargin: true,
            },
            {
                title: "not enough im and liquidation free",
                collateralBalance: 0,
                takerInfos: [
                    {
                        baseBalanceShare: 25,
                        quoteBalance: 0,
                    },
                    {
                        baseBalanceShare: 30,
                        quoteBalance: 0,
                    },
                ],
                makerInfos: [
                    {
                        liquidity: 0,
                        cumBaseSharePerLiquidityX96: 0,
                        cumQuotePerLiquidityX96: 0,
                    },
                    {
                        liquidity: 0,
                        cumBaseSharePerLiquidityX96: 0,
                        cumQuotePerLiquidityX96: 0,
                    },
                ],
                poolInfos: [
                    {
                        base: 10000,
                        quote: 40000,
                        totalLiquidity: 20000,
                        cumBasePerLiquidityX96: 0,
                        cumQuotePerLiquidityX96: 0,
                        baseBalancePerShareX96: Q96,
                    },
                    {
                        base: 10000,
                        quote: 40000,
                        totalLiquidity: 20000,
                        cumBasePerLiquidityX96: 0,
                        cumQuotePerLiquidityX96: 0,
                        baseBalancePerShareX96: Q96,
                    },
                ],
                totalAccountValue: 220,
                positionShares: [25, 30],
                positionNotionals: [100, 120],
                totalPositionNotional: 220,
                openPositionShares: [25, 30],
                openPositionNotionals: [100, 120],
                totalOpenPositionNotional: 220,
                hasEnoughMaintenanceMargin: true,
                hasEnoughInitialMargin: true,
            },
            {
                title: "not enough im and not liquidation free negative base",
                collateralBalance: 0,
                takerInfos: [
                    {
                        baseBalanceShare: 25,
                        quoteBalance: 0,
                    },
                    {
                        baseBalanceShare: -1,
                        quoteBalance: 0,
                    },
                ],
                makerInfos: [
                    {
                        liquidity: 0,
                        cumBaseSharePerLiquidityX96: 0,
                        cumQuotePerLiquidityX96: 0,
                    },
                    {
                        liquidity: 0,
                        cumBaseSharePerLiquidityX96: 0,
                        cumQuotePerLiquidityX96: 0,
                    },
                ],
                poolInfos: [
                    {
                        base: 10000,
                        quote: 40000,
                        totalLiquidity: 20000,
                        cumBasePerLiquidityX96: 0,
                        cumQuotePerLiquidityX96: 0,
                        baseBalancePerShareX96: Q96,
                    },
                    {
                        base: 10000,
                        quote: 40000,
                        totalLiquidity: 20000,
                        cumBasePerLiquidityX96: 0,
                        cumQuotePerLiquidityX96: 0,
                        baseBalancePerShareX96: Q96,
                    },
                ],
                totalAccountValue: 96,
                positionShares: [25, -1],
                positionNotionals: [100, -4],
                totalPositionNotional: 104,
                openPositionShares: [25, 1],
                openPositionNotionals: [100, 4],
                totalOpenPositionNotional: 104,
                hasEnoughMaintenanceMargin: true,
                hasEnoughInitialMargin: false,
            },
            {
                title: "not enough im and not liquidation free negative quote",
                collateralBalance: 0,
                takerInfos: [
                    {
                        baseBalanceShare: 25,
                        quoteBalance: 0,
                    },
                    {
                        baseBalanceShare: 30,
                        quoteBalance: -1,
                    },
                ],
                makerInfos: [
                    {
                        liquidity: 0,
                        cumBaseSharePerLiquidityX96: 0,
                        cumQuotePerLiquidityX96: 0,
                    },
                    {
                        liquidity: 0,
                        cumBaseSharePerLiquidityX96: 0,
                        cumQuotePerLiquidityX96: 0,
                    },
                ],
                poolInfos: [
                    {
                        base: 10000,
                        quote: 40000,
                        totalLiquidity: 20000,
                        cumBasePerLiquidityX96: 0,
                        cumQuotePerLiquidityX96: 0,
                        baseBalancePerShareX96: Q96,
                    },
                    {
                        base: 10000,
                        quote: 40000,
                        totalLiquidity: 20000,
                        cumBasePerLiquidityX96: 0,
                        cumQuotePerLiquidityX96: 0,
                        baseBalancePerShareX96: Q96,
                    },
                ],
                totalAccountValue: 219,
                positionShares: [25, 30],
                positionNotionals: [100, 120],
                totalPositionNotional: 220,
                openPositionShares: [25, 30],
                openPositionNotionals: [100, 120],
                totalOpenPositionNotional: 220,
                hasEnoughMaintenanceMargin: true,
                hasEnoughInitialMargin: false,
            },
        ].forEach(test => {
            it(test.title, async () => {
                await exchange.connect(owner).setImRatio(10e4)
                await exchange.connect(owner).setMmRatio(5e4)

                await exchange.setAccountInfo(
                    alice.address,
                    {
                        collateralBalance: test.collateralBalance,
                    },
                    markets.map(market => market.address),
                )

                for (let i = 0; i < markets.length; i++) {
                    await exchange.setTakerInfo(alice.address, markets[i].address, test.takerInfos[i])
                    await exchange.setMakerInfo(alice.address, markets[i].address, test.makerInfos[i])
                    await markets[i].setPoolInfo(test.poolInfos[i])
                }

                for (let i = 0; i < markets.length; i++) {
                    expect(await exchange.getPositionShare(alice.address, markets[i].address)).to.eq(
                        test.positionShares[i],
                    )
                    expect(await exchange.getPositionNotional(alice.address, markets[i].address)).to.eq(
                        test.positionNotionals[i],
                    )
                    expect(await exchange.getOpenPositionShare(alice.address, markets[i].address)).to.eq(
                        test.openPositionShares[i],
                    )
                    expect(await exchange.getOpenPositionNotional(alice.address, markets[i].address)).to.eq(
                        test.openPositionNotionals[i],
                    )
                }

                expect(await exchange.getTotalAccountValue(alice.address)).to.eq(test.totalAccountValue)
                expect(await exchange.getTotalPositionNotional(alice.address)).to.eq(test.totalPositionNotional)
                expect(await exchange.getTotalOpenPositionNotional(alice.address)).to.eq(test.totalOpenPositionNotional)
                expect(await exchange.hasEnoughMaintenanceMargin(alice.address)).to.eq(test.hasEnoughMaintenanceMargin)
                expect(await exchange.hasEnoughInitialMargin(alice.address)).to.eq(test.hasEnoughInitialMargin)
            })
        })
    })
})
