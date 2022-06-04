import { expect } from "chai"
import { waffle } from "hardhat"
import { TestPerpdexExchange, TestPerpdexMarket } from "../../typechain"
import { createPerpdexExchangeFixture } from "./fixtures"
import { BigNumber, Wallet } from "ethers"

describe("PerpdexExchange getters", () => {
    let loadFixture = waffle.createFixtureLoader(waffle.provider.getWallets())
    let fixture

    let exchange: TestPerpdexExchange
    let market: TestPerpdexMarket
    let owner: Wallet
    let alice: Wallet

    const Q96 = BigNumber.from(2).pow(96)

    beforeEach(async () => {
        fixture = await loadFixture(createPerpdexExchangeFixture())
        exchange = fixture.perpdexExchange
        market = fixture.perpdexMarket
        owner = fixture.owner
        alice = fixture.alice
    })

    describe("getTakerInfo", async () => {
        it("ok", async () => {
            await exchange.setTakerInfo(alice.address, market.address, {
                baseBalanceShare: 1,
                quoteBalance: 2,
            })
            const takerInfo = await exchange.getTakerInfo(alice.address, market.address)
            expect(takerInfo.baseBalanceShare).to.eq(1)
            expect(takerInfo.quoteBalance).to.eq(2)
        })
    })

    describe("getMakerInfo", async () => {
        it("ok", async () => {
            await exchange.setMakerInfo(alice.address, market.address, {
                baseDebtShare: 1,
                quoteDebt: 2,
                liquidity: 3,
                cumDeleveragedBaseSharePerLiquidityX96: 4,
                cumDeleveragedQuotePerLiquidityX96: 5,
            })
            const makerInfo = await exchange.getMakerInfo(alice.address, market.address)
            expect(makerInfo.baseDebtShare).to.eq(1)
            expect(makerInfo.quoteDebt).to.eq(2)
            expect(makerInfo.liquidity).to.eq(3)
            expect(makerInfo.cumDeleveragedBaseSharePerLiquidityX96).to.eq(4)
            expect(makerInfo.cumDeleveragedQuotePerLiquidityX96).to.eq(5)
        })
    })

    describe("getAccountMarkets", async () => {
        it("ok", async () => {
            await exchange.setAccountInfo(
                alice.address,
                {
                    collateralBalance: 0,
                },
                [market.address],
            )
            const markets = await exchange.getAccountMarkets(alice.address)
            expect(markets.length).to.eq(1)
            expect(markets[0]).to.eq(market.address)
        })
    })

    describe("AccountLibrary getters single market", async () => {
        ;[
            {
                title: "empty pool, zero",
                collateralBalance: 0,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                makerInfo: {
                    baseDebtShare: 0,
                    quoteDebt: 0,
                    liquidity: 0,
                    cumDeleveragedBaseSharePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                },
                poolInfo: {
                    base: 0,
                    quote: 0,
                    totalLiquidity: 0,
                    cumDeleveragedBasePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                    baseBalancePerShareX96: Q96,
                },
                totalAccountValue: 0,
                positionShare: 0,
                positionNotional: 0,
                openPositionShare: 0,
                openPositionNotional: 0,
                hasEnoughMaintenanceMargin: true,
                hasEnoughInitialMargin: true,
            },
            {
                title: "empty pool, no position",
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                makerInfo: {
                    baseDebtShare: 0,
                    quoteDebt: 0,
                    liquidity: 0,
                    cumDeleveragedBaseSharePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                },
                poolInfo: {
                    base: 0,
                    quote: 0,
                    totalLiquidity: 0,
                    cumDeleveragedBasePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                    baseBalancePerShareX96: Q96,
                },
                totalAccountValue: 100,
                positionShare: 0,
                positionNotional: 0,
                openPositionShare: 0,
                openPositionNotional: 0,
                hasEnoughMaintenanceMargin: true,
                hasEnoughInitialMargin: true,
            },
            {
                title: "empty pool, negative collateral",
                collateralBalance: -50,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                makerInfo: {
                    baseDebtShare: 0,
                    quoteDebt: 0,
                    liquidity: 0,
                    cumDeleveragedBaseSharePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                },
                poolInfo: {
                    base: 0,
                    quote: 0,
                    totalLiquidity: 0,
                    cumDeleveragedBasePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                    baseBalancePerShareX96: Q96,
                },
                totalAccountValue: -50,
                positionShare: 0,
                positionNotional: 0,
                openPositionShare: 0,
                openPositionNotional: 0,
                hasEnoughMaintenanceMargin: false,
                hasEnoughInitialMargin: false,
            },
            {
                title: "zero",
                collateralBalance: 0,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                makerInfo: {
                    baseDebtShare: 0,
                    quoteDebt: 0,
                    liquidity: 0,
                    cumDeleveragedBaseSharePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                },
                poolInfo: {
                    base: 10000,
                    quote: 10000,
                    totalLiquidity: 10000,
                    cumDeleveragedBasePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                    baseBalancePerShareX96: Q96,
                },
                totalAccountValue: 0,
                positionShare: 0,
                positionNotional: 0,
                openPositionShare: 0,
                openPositionNotional: 0,
                hasEnoughMaintenanceMargin: true,
                hasEnoughInitialMargin: true,
            },
            {
                title: "no position",
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                makerInfo: {
                    baseDebtShare: 0,
                    quoteDebt: 0,
                    liquidity: 0,
                    cumDeleveragedBaseSharePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                },
                poolInfo: {
                    base: 10000,
                    quote: 10000,
                    totalLiquidity: 10000,
                    cumDeleveragedBasePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                    baseBalancePerShareX96: Q96,
                },
                totalAccountValue: 100,
                positionShare: 0,
                positionNotional: 0,
                openPositionShare: 0,
                openPositionNotional: 0,
                hasEnoughMaintenanceMargin: true,
                hasEnoughInitialMargin: true,
            },
            {
                title: "negative collateral",
                collateralBalance: -50,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                makerInfo: {
                    baseDebtShare: 0,
                    quoteDebt: 0,
                    liquidity: 0,
                    cumDeleveragedBaseSharePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                },
                poolInfo: {
                    base: 10000,
                    quote: 10000,
                    totalLiquidity: 10000,
                    cumDeleveragedBasePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                    baseBalancePerShareX96: Q96,
                },
                totalAccountValue: -50,
                positionShare: 0,
                positionNotional: 0,
                openPositionShare: 0,
                openPositionNotional: 0,
                hasEnoughMaintenanceMargin: false,
                hasEnoughInitialMargin: false,
            },
            {
                title: "long",
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 25,
                    quoteBalance: -100,
                },
                makerInfo: {
                    baseDebtShare: 0,
                    quoteDebt: 0,
                    liquidity: 0,
                    cumDeleveragedBaseSharePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                },
                poolInfo: {
                    base: 10000,
                    quote: 40000,
                    totalLiquidity: 20000,
                    cumDeleveragedBasePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                    baseBalancePerShareX96: Q96,
                },
                totalAccountValue: 100,
                positionShare: 25,
                positionNotional: 100,
                openPositionShare: 25,
                openPositionNotional: 100,
                hasEnoughMaintenanceMargin: true,
                hasEnoughInitialMargin: true,
            },
            {
                title: "short",
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: -25,
                    quoteBalance: 100,
                },
                makerInfo: {
                    baseDebtShare: 0,
                    quoteDebt: 0,
                    liquidity: 0,
                    cumDeleveragedBaseSharePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                },
                poolInfo: {
                    base: 10000,
                    quote: 40000,
                    totalLiquidity: 20000,
                    cumDeleveragedBasePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                    baseBalancePerShareX96: Q96,
                },
                totalAccountValue: 100,
                positionShare: -25,
                positionNotional: -100,
                openPositionShare: 25,
                openPositionNotional: 100,
                hasEnoughMaintenanceMargin: true,
                hasEnoughInitialMargin: true,
            },
            {
                title: "long profit",
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 25,
                    quoteBalance: -50,
                },
                makerInfo: {
                    baseDebtShare: 0,
                    quoteDebt: 0,
                    liquidity: 0,
                    cumDeleveragedBaseSharePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                },
                poolInfo: {
                    base: 10000,
                    quote: 40000,
                    totalLiquidity: 20000,
                    cumDeleveragedBasePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                    baseBalancePerShareX96: Q96,
                },
                totalAccountValue: 150,
                positionShare: 25,
                positionNotional: 100,
                openPositionShare: 25,
                openPositionNotional: 100,
                hasEnoughMaintenanceMargin: true,
                hasEnoughInitialMargin: true,
            },
            {
                title: "long profit",
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 25,
                    quoteBalance: -50,
                },
                makerInfo: {
                    baseDebtShare: 0,
                    quoteDebt: 0,
                    liquidity: 0,
                    cumDeleveragedBaseSharePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                },
                poolInfo: {
                    base: 10000,
                    quote: 40000,
                    totalLiquidity: 20000,
                    cumDeleveragedBasePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                    baseBalancePerShareX96: Q96.mul(2),
                },
                totalAccountValue: 150,
                positionShare: 25,
                positionNotional: 100,
                openPositionShare: 25,
                openPositionNotional: 100,
                hasEnoughMaintenanceMargin: true,
                hasEnoughInitialMargin: true,
            },
            {
                title: "long loss",
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 25,
                    quoteBalance: -200,
                },
                makerInfo: {
                    baseDebtShare: 0,
                    quoteDebt: 0,
                    liquidity: 0,
                    cumDeleveragedBaseSharePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                },
                poolInfo: {
                    base: 10000,
                    quote: 40000,
                    totalLiquidity: 20000,
                    cumDeleveragedBasePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                    baseBalancePerShareX96: Q96,
                },
                totalAccountValue: 0,
                positionShare: 25,
                positionNotional: 100,
                openPositionShare: 25,
                openPositionNotional: 100,
                hasEnoughMaintenanceMargin: false,
                hasEnoughInitialMargin: false,
            },
            {
                title: "short profit",
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: -25,
                    quoteBalance: 150,
                },
                makerInfo: {
                    baseDebtShare: 0,
                    quoteDebt: 0,
                    liquidity: 0,
                    cumDeleveragedBaseSharePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                },
                poolInfo: {
                    base: 10000,
                    quote: 40000,
                    totalLiquidity: 20000,
                    cumDeleveragedBasePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                    baseBalancePerShareX96: Q96,
                },
                totalAccountValue: 150,
                positionShare: -25,
                positionNotional: -100,
                openPositionShare: 25,
                openPositionNotional: 100,
                hasEnoughMaintenanceMargin: true,
                hasEnoughInitialMargin: true,
            },
            {
                title: "short loss",
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: -25,
                    quoteBalance: 0,
                },
                makerInfo: {
                    baseDebtShare: 0,
                    quoteDebt: 0,
                    liquidity: 0,
                    cumDeleveragedBaseSharePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                },
                poolInfo: {
                    base: 10000,
                    quote: 40000,
                    totalLiquidity: 20000,
                    cumDeleveragedBasePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                    baseBalancePerShareX96: Q96,
                },
                totalAccountValue: 0,
                positionShare: -25,
                positionNotional: -100,
                openPositionShare: 25,
                openPositionNotional: 100,
                hasEnoughMaintenanceMargin: false,
                hasEnoughInitialMargin: false,
            },
            {
                title: "long negative",
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 25,
                    quoteBalance: -250,
                },
                makerInfo: {
                    baseDebtShare: 0,
                    quoteDebt: 0,
                    liquidity: 0,
                    cumDeleveragedBaseSharePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                },
                poolInfo: {
                    base: 10000,
                    quote: 40000,
                    totalLiquidity: 20000,
                    cumDeleveragedBasePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                    baseBalancePerShareX96: Q96,
                },
                totalAccountValue: -50,
                positionShare: 25,
                positionNotional: 100,
                openPositionShare: 25,
                openPositionNotional: 100,
                hasEnoughMaintenanceMargin: false,
                hasEnoughInitialMargin: false,
            },
            {
                title: "maker",
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                makerInfo: {
                    baseDebtShare: 25,
                    quoteDebt: 100,
                    liquidity: 50,
                    cumDeleveragedBaseSharePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                },
                poolInfo: {
                    base: 10000,
                    quote: 40000,
                    totalLiquidity: 20000,
                    cumDeleveragedBasePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                    baseBalancePerShareX96: Q96,
                },
                totalAccountValue: 100,
                positionShare: 0,
                positionNotional: 0,
                openPositionShare: 25,
                openPositionNotional: 100,
                hasEnoughMaintenanceMargin: true,
                hasEnoughInitialMargin: true,
            },
            {
                title: "maker long",
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                makerInfo: {
                    baseDebtShare: 25,
                    quoteDebt: 100,
                    liquidity: 50,
                    cumDeleveragedBaseSharePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                },
                poolInfo: {
                    base: 20000,
                    quote: 20000,
                    totalLiquidity: 20000,
                    cumDeleveragedBasePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                    baseBalancePerShareX96: Q96,
                },
                totalAccountValue: 75,
                positionShare: 25,
                positionNotional: 25,
                openPositionShare: 75,
                openPositionNotional: 75,
                hasEnoughMaintenanceMargin: true,
                hasEnoughInitialMargin: true,
            },
            {
                title: "maker long rebase",
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                makerInfo: {
                    baseDebtShare: 25,
                    quoteDebt: 100,
                    liquidity: 50,
                    cumDeleveragedBaseSharePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                },
                poolInfo: {
                    base: 20000,
                    quote: 20000,
                    totalLiquidity: 20000,
                    cumDeleveragedBasePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                    baseBalancePerShareX96: Q96.div(2),
                },
                totalAccountValue: 75,
                positionShare: 25,
                positionNotional: 25,
                openPositionShare: 75,
                openPositionNotional: 75,
                hasEnoughMaintenanceMargin: true,
                hasEnoughInitialMargin: true,
            },
            {
                title: "maker short",
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                makerInfo: {
                    baseDebtShare: 50,
                    quoteDebt: 50,
                    liquidity: 50,
                    cumDeleveragedBaseSharePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                },
                poolInfo: {
                    base: 10000,
                    quote: 40000,
                    totalLiquidity: 20000,
                    cumDeleveragedBasePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                    baseBalancePerShareX96: Q96,
                },
                totalAccountValue: 50,
                positionShare: -25,
                positionNotional: -100,
                openPositionShare: 50,
                openPositionNotional: 200,
                hasEnoughMaintenanceMargin: true,
                hasEnoughInitialMargin: true,
            },
            {
                title: "maker + taker",
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 25,
                    quoteBalance: -100,
                },
                makerInfo: {
                    baseDebtShare: 50,
                    quoteDebt: 50,
                    liquidity: 50,
                    cumDeleveragedBaseSharePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                },
                poolInfo: {
                    base: 10000,
                    quote: 40000,
                    totalLiquidity: 20000,
                    cumDeleveragedBasePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                    baseBalancePerShareX96: Q96,
                },
                totalAccountValue: 50,
                positionShare: 0,
                positionNotional: 0,
                openPositionShare: 25,
                openPositionNotional: 100,
                hasEnoughMaintenanceMargin: true,
                hasEnoughInitialMargin: true,
            },
            {
                title: "maker not enough im",
                collateralBalance: 9,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                makerInfo: {
                    baseDebtShare: 25,
                    quoteDebt: 100,
                    liquidity: 50,
                    cumDeleveragedBaseSharePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                },
                poolInfo: {
                    base: 10000,
                    quote: 40000,
                    totalLiquidity: 20000,
                    cumDeleveragedBasePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                    baseBalancePerShareX96: Q96,
                },
                totalAccountValue: 9,
                positionShare: 0,
                positionNotional: 0,
                openPositionShare: 25,
                openPositionNotional: 100,
                hasEnoughMaintenanceMargin: true,
                hasEnoughInitialMargin: false,
            },
            {
                title: "maker deleverage",
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                makerInfo: {
                    baseDebtShare: 25,
                    quoteDebt: 100,
                    liquidity: 50,
                    cumDeleveragedBaseSharePerLiquidityX96: Q96.mul(10),
                    cumDeleveragedQuotePerLiquidityX96: Q96.mul(20),
                },
                poolInfo: {
                    base: 10000,
                    quote: 40000,
                    totalLiquidity: 20000,
                    cumDeleveragedBasePerLiquidityX96: Q96.mul(11),
                    cumDeleveragedQuotePerLiquidityX96: Q96.mul(22),
                    baseBalancePerShareX96: Q96,
                },
                totalAccountValue: 100 + 50 * 4 + 100,
                positionShare: 50,
                positionNotional: 200,
                openPositionShare: 75,
                openPositionNotional: 300,
                hasEnoughMaintenanceMargin: true,
                hasEnoughInitialMargin: true,
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
                    [market.address],
                )

                await exchange.setTakerInfo(alice.address, market.address, test.takerInfo)
                await exchange.setMakerInfo(alice.address, market.address, test.makerInfo)

                await market.setPoolInfo(test.poolInfo)

                expect(await exchange.getTotalAccountValue(alice.address)).to.eq(test.totalAccountValue)
                expect(await exchange.getPositionShare(alice.address, market.address)).to.eq(test.positionShare)
                expect(await exchange.getPositionNotional(alice.address, market.address)).to.eq(test.positionNotional)
                expect(await exchange.getTotalPositionNotional(alice.address)).to.eq(Math.abs(test.positionNotional))
                expect(await exchange.getOpenPositionShare(alice.address, market.address)).to.eq(test.openPositionShare)
                expect(await exchange.getOpenPositionNotional(alice.address, market.address)).to.eq(
                    test.openPositionNotional,
                )
                expect(await exchange.getTotalOpenPositionNotional(alice.address)).to.eq(test.openPositionNotional)
                expect(await exchange.hasEnoughMaintenanceMargin(alice.address)).to.eq(test.hasEnoughMaintenanceMargin)
                expect(await exchange.hasEnoughInitialMargin(alice.address)).to.eq(test.hasEnoughInitialMargin)
            })
        })
    })
})
