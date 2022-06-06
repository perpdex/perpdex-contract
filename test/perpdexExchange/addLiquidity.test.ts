import { expect } from "chai"
import { waffle } from "hardhat"
import { TestPerpdexExchange, TestPerpdexMarket } from "../../typechain"
import { createPerpdexExchangeFixture } from "./fixtures"
import { BigNumber, Wallet } from "ethers"

describe("PerpdexExchange addLiquidity", () => {
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

    describe("various cases", async () => {
        ;[
            {
                title: "add",
                base: 100,
                quote: 200,
                minBase: 100,
                minQuote: 100,
                collateralBalance: 10,
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
                afterCollateralBalance: 10,
                afterTakerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                afterMakerInfo: {
                    baseDebtShare: 100,
                    quoteDebt: 100,
                    liquidity: 100,
                    cumDeleveragedBaseSharePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                },
            },
            {
                title: "deleverage",
                base: 100,
                quote: 200,
                minBase: 0,
                minQuote: 0,
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                makerInfo: {
                    baseDebtShare: 0,
                    quoteDebt: 0,
                    liquidity: 1,
                    cumDeleveragedBaseSharePerLiquidityX96: 0,
                    cumDeleveragedQuotePerLiquidityX96: 0,
                },
                poolInfo: {
                    base: 10000,
                    quote: 10000,
                    totalLiquidity: 10000,
                    cumDeleveragedBasePerLiquidityX96: Q96.mul(2),
                    cumDeleveragedQuotePerLiquidityX96: Q96.mul(3),
                    baseBalancePerShareX96: Q96,
                },
                afterCollateralBalance: 100,
                afterTakerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                afterMakerInfo: {
                    baseDebtShare: 98,
                    quoteDebt: 97,
                    liquidity: 101,
                    cumDeleveragedBaseSharePerLiquidityX96: Q96.mul(2),
                    cumDeleveragedQuotePerLiquidityX96: Q96.mul(3),
                },
            },
            {
                title: "minBase condition",
                base: 100,
                quote: 200,
                minBase: 101,
                minQuote: 0,
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
                revertedWith: "ML_AL: too small output base",
            },
            {
                title: "market disallowed",
                base: 100,
                quote: 200,
                minBase: 0,
                minQuote: 0,
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
                isMarketAllowed: false,
                revertedWith: "ML_AL: add liquidity forbidden",
            },
            {
                title: "not enough mm",
                base: 100,
                quote: 100,
                minBase: 0,
                minQuote: 0,
                collateralBalance: 9,
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
                revertedWith: "ML_AL: not enough im",
            },
        ].forEach(test => {
            it(test.title, async () => {
                await exchange.setAccountInfo(
                    alice.address,
                    {
                        collateralBalance: test.collateralBalance,
                    },
                    [market.address],
                )
                await exchange.setTakerInfo(alice.address, market.address, test.takerInfo)
                await exchange.setMakerInfo(alice.address, market.address, test.makerInfo)

                if (test.isMarketAllowed !== void 0) {
                    await exchange.connect(owner).setIsMarketAllowed(market.address, test.isMarketAllowed)
                }

                if (test.poolInfo) {
                    await market.setPoolInfo(test.poolInfo)
                }

                const res = expect(
                    exchange.connect(alice).addLiquidity({
                        market: market.address,
                        base: test.base,
                        quote: test.quote,
                        minBase: test.minBase,
                        minQuote: test.minQuote,
                        deadline: deadline,
                    }),
                )

                if (test.revertedWith === void 0) {
                    await res.to.emit(exchange, "LiquidityAdded")

                    const accountInfo = await exchange.accountInfos(alice.address)
                    expect(accountInfo.collateralBalance).to.eq(test.afterCollateralBalance)

                    const takerInfo = await exchange.getTakerInfo(alice.address, market.address)
                    expect(takerInfo.baseBalanceShare).to.eq(test.afterTakerInfo.baseBalanceShare)
                    expect(takerInfo.quoteBalance).to.eq(test.afterTakerInfo.quoteBalance)

                    const makerInfo = await exchange.getMakerInfo(alice.address, market.address)
                    expect(makerInfo.baseDebtShare).to.eq(test.afterMakerInfo.baseDebtShare)
                    expect(makerInfo.quoteDebt).to.eq(test.afterMakerInfo.quoteDebt)
                    expect(makerInfo.liquidity).to.eq(test.afterMakerInfo.liquidity)
                    expect(makerInfo.cumDeleveragedBaseSharePerLiquidityX96).to.eq(
                        test.afterMakerInfo.cumDeleveragedBaseSharePerLiquidityX96,
                    )
                    expect(makerInfo.cumDeleveragedQuotePerLiquidityX96).to.eq(
                        test.afterMakerInfo.cumDeleveragedQuotePerLiquidityX96,
                    )
                } else {
                    await res.to.revertedWith(test.revertedWith)
                }
            })
        })
    })
})
