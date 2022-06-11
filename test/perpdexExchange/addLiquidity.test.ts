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

    describe("various cases", () => {
        ;[
            {
                title: "initial",
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
                    liquidity: 0,
                    cumBaseSharePerLiquidityX96: 0,
                    cumQuotePerLiquidityX96: 0,
                },
                outputBase: 100,
                outputQuote: 100,
                afterCollateralBalance: 10,
                afterTakerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                afterMakerInfo: {
                    liquidity: 100,
                    cumBaseSharePerLiquidityX96: Q96, // debt 100
                    cumQuotePerLiquidityX96: Q96, // debt 100
                },
            },
            {
                title: "add",
                base: 100,
                quote: 200,
                minBase: 100,
                minQuote: 100,
                collateralBalance: 80,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                makerInfo: {
                    liquidity: 400,
                    cumBaseSharePerLiquidityX96: Q96.div(4), // debt 100
                    cumQuotePerLiquidityX96: Q96.div(4), // debt 100
                },
                outputBase: 100,
                outputQuote: 100,
                afterCollateralBalance: 80,
                afterTakerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                afterMakerInfo: {
                    liquidity: 500,
                    cumBaseSharePerLiquidityX96: Q96.mul(2).div(5), // debt 200
                    cumQuotePerLiquidityX96: Q96.mul(2).div(5), // debt 200
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
                    liquidity: 1,
                    cumBaseSharePerLiquidityX96: 0,
                    cumQuotePerLiquidityX96: 0,
                },
                poolInfo: {
                    base: 10000,
                    quote: 10000,
                    totalLiquidity: 10000,
                    cumBasePerLiquidityX96: Q96.mul(2),
                    cumQuotePerLiquidityX96: Q96.mul(3),
                    baseBalancePerShareX96: Q96,
                },
                outputBase: 100,
                outputQuote: 100,
                afterCollateralBalance: 100,
                afterTakerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                afterMakerInfo: {
                    liquidity: 101,
                    cumBaseSharePerLiquidityX96: Q96.mul(2).add(
                        Q96.mul(98).div(101), // debt 98
                    ),
                    cumQuotePerLiquidityX96: Q96.mul(3).add(
                        Q96.mul(97).div(101), // debt 97
                    ),
                },
                cumBaseSharePerLiquidityX96: Q96.mul(2),
                cumQuotePerLiquidityX96: Q96.mul(3),
            },
            {
                title: "deleverage add",
                base: 100,
                quote: 200,
                minBase: 100,
                minQuote: 100,
                collateralBalance: 80,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                makerInfo: {
                    liquidity: 400,
                    cumBaseSharePerLiquidityX96: Q96.div(4), // 700
                    cumQuotePerLiquidityX96: Q96.div(4), // 1100
                },
                poolInfo: {
                    base: 10000,
                    quote: 10000,
                    totalLiquidity: 10000,
                    cumBasePerLiquidityX96: Q96.mul(2),
                    cumQuotePerLiquidityX96: Q96.mul(3),
                    baseBalancePerShareX96: Q96,
                },
                outputBase: 100,
                outputQuote: 100,
                afterCollateralBalance: 80,
                afterTakerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                afterMakerInfo: {
                    liquidity: 500,
                    cumBaseSharePerLiquidityX96: Q96.mul(2 * 5 - 6).div(5), // 600
                    cumQuotePerLiquidityX96: Q96.mul(3 * 5 - 10)
                        .div(5)
                        .sub(1), // 1000 + rounding error
                },
                cumBaseSharePerLiquidityX96: Q96.mul(2),
                cumQuotePerLiquidityX96: Q96.mul(3),
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
                    liquidity: 0,
                    cumBaseSharePerLiquidityX96: 0,
                    cumQuotePerLiquidityX96: 0,
                },
                revertedWith: "ML_AL: too small output base",
            },
            {
                title: "minQuote condition",
                base: 100,
                quote: 200,
                minBase: 0,
                minQuote: 101,
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                makerInfo: {
                    liquidity: 0,
                    cumBaseSharePerLiquidityX96: 0,
                    cumQuotePerLiquidityX96: 0,
                },
                revertedWith: "ML_AL: too small output quote",
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
                    liquidity: 0,
                    cumBaseSharePerLiquidityX96: 0,
                    cumQuotePerLiquidityX96: 0,
                },
                isMarketAllowed: false,
                revertedWith: "PE_CMA: market not allowed",
            },
            {
                title: "not enough im",
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
                    liquidity: 0,
                    cumBaseSharePerLiquidityX96: 0,
                    cumQuotePerLiquidityX96: 0,
                },
                revertedWith: "ML_AL: not enough im",
            },
            {
                title: "event",
                base: 100,
                quote: 400,
                minBase: 0,
                minQuote: 0,
                collateralBalance: 100,
                takerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                makerInfo: {
                    liquidity: 0,
                    cumBaseSharePerLiquidityX96: 0,
                    cumQuotePerLiquidityX96: 0,
                },
                poolInfo: {
                    base: 10000,
                    quote: 40000,
                    totalLiquidity: 20000,
                    cumBasePerLiquidityX96: 0,
                    cumQuotePerLiquidityX96: 0,
                    baseBalancePerShareX96: Q96.mul(2),
                },
                outputBase: 100,
                outputQuote: 400,
                afterCollateralBalance: 100,
                afterTakerInfo: {
                    baseBalanceShare: 0,
                    quoteBalance: 0,
                },
                afterMakerInfo: {
                    liquidity: 200,
                    cumBaseSharePerLiquidityX96: Q96.div(2), // debt 100
                    cumQuotePerLiquidityX96: Q96.mul(2), // debt 400
                },
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
                    const sharePrice = test.poolInfo ? Q96.mul(test.poolInfo.quote).div(test.poolInfo.base) : Q96

                    await res.to
                        .emit(exchange, "LiquidityAdded")
                        .withArgs(
                            alice.address,
                            market.address,
                            test.outputBase,
                            test.outputQuote,
                            test.afterMakerInfo.liquidity - test.makerInfo.liquidity,
                            test.afterMakerInfo.cumBaseSharePerLiquidityX96,
                            test.afterMakerInfo.cumQuotePerLiquidityX96,
                            test.poolInfo ? test.poolInfo.baseBalancePerShareX96 : Q96,
                            sharePrice,
                        )

                    const accountInfo = await exchange.accountInfos(alice.address)
                    expect(accountInfo.collateralBalance).to.eq(test.afterCollateralBalance)

                    const takerInfo = await exchange.getTakerInfo(alice.address, market.address)
                    expect(takerInfo.baseBalanceShare).to.eq(test.afterTakerInfo.baseBalanceShare)
                    expect(takerInfo.quoteBalance).to.eq(test.afterTakerInfo.quoteBalance)

                    const makerInfo = await exchange.getMakerInfo(alice.address, market.address)
                    expect(makerInfo.liquidity).to.eq(test.afterMakerInfo.liquidity)
                    expect(makerInfo.cumBaseSharePerLiquidityX96).to.eq(test.afterMakerInfo.cumBaseSharePerLiquidityX96)
                    expect(makerInfo.cumQuotePerLiquidityX96).to.eq(test.afterMakerInfo.cumQuotePerLiquidityX96)
                } else {
                    await res.to.revertedWith(test.revertedWith)
                }
            })
        })
    })
})
