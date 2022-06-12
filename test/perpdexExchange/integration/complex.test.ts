import { expect } from "chai"
import { waffle } from "hardhat"
import { TestPerpdexExchange, TestPerpdexMarket } from "../../../typechain"
import { createPerpdexExchangeFixture } from "../fixtures"
import { BigNumber, Wallet } from "ethers"
import { getTimestamp, setNextTimestamp } from "../../helper/time"
import { MockContract } from "ethereum-waffle"

describe("PerpdexExchange complex situation", () => {
    let loadFixture = waffle.createFixtureLoader(waffle.provider.getWallets())
    let fixture

    let exchange: TestPerpdexExchange
    let market: TestPerpdexMarket
    let markets: TestPerpdexMarket[]
    let traders: Wallet[]
    let owner: Wallet
    let alice: Wallet
    let bob: Wallet
    let carol: Wallet
    let priceFeed: MockContract

    const PoolAmount = BigNumber.from(10).pow(18)
    const Q96 = BigNumber.from(2).pow(96)
    const X10_18 = BigNumber.from(10).pow(18)
    const deadline = Q96
    const epsilon = 10

    const long = async (trader, amount, idx = 0) => {
        return exchange.connect(trader).trade({
            trader: trader.address,
            market: markets[idx].address,
            isBaseToQuote: false,
            isExactInput: false,
            amount: amount,
            oppositeAmountBound: BigNumber.from(amount).mul(10),
            deadline: deadline,
        })
    }

    const longLiq = async (trader, liquidator, amount, idx = 0) => {
        return exchange.connect(liquidator).trade({
            trader: trader.address,
            market: markets[idx].address,
            isBaseToQuote: false,
            isExactInput: false,
            amount: amount,
            oppositeAmountBound: BigNumber.from(amount).mul(10),
            deadline: deadline,
        })
    }

    const shortLiq = async (trader, liquidator, amount, idx = 0) => {
        return exchange.connect(liquidator).trade({
            trader: trader.address,
            market: markets[idx].address,
            isBaseToQuote: true,
            isExactInput: true,
            amount: amount,
            oppositeAmountBound: 0,
            deadline: deadline,
        })
    }

    const short = async (trader, amount, idx = 0) => {
        return exchange.connect(trader).trade({
            trader: trader.address,
            market: markets[idx].address,
            isBaseToQuote: true,
            isExactInput: true,
            amount: amount,
            oppositeAmountBound: 0,
            deadline: deadline,
        })
    }

    const maxLong = async (trader, idx = 0) => {
        return exchange.maxTrade({
            trader: trader.address,
            market: markets[idx].address,
            caller: trader.address,
            isBaseToQuote: false,
            isExactInput: false,
        })
    }

    const maxShort = async (trader, idx = 0) => {
        return exchange.maxTrade({
            trader: trader.address,
            market: markets[idx].address,
            caller: trader.address,
            isBaseToQuote: true,
            isExactInput: true,
        })
    }

    const maxLongLiq = async (trader, liquidator, idx = 0) => {
        return exchange.maxTrade({
            trader: trader.address,
            market: markets[idx].address,
            caller: liquidator.address,
            isBaseToQuote: false,
            isExactInput: false,
        })
    }

    const maxShortLiq = async (trader, liquidator, idx = 0) => {
        return exchange.maxTrade({
            trader: trader.address,
            market: markets[idx].address,
            caller: liquidator.address,
            isBaseToQuote: true,
            isExactInput: true,
        })
    }

    const addLiquidity = async (trader, base, quote, idx = 0) => {
        return exchange.connect(trader).addLiquidity({
            market: markets[idx].address,
            base: base,
            quote: quote,
            minBase: 0,
            minQuote: 0,
            deadline: deadline,
        })
    }

    const removeLiquidity = async (trader, liquidity, idx = 0) => {
        return exchange.connect(trader).removeLiquidity({
            trader: trader.address,
            market: markets[idx].address,
            liquidity: liquidity,
            minBase: 0,
            minQuote: 0,
            deadline: deadline,
        })
    }

    const deposit = async (trader, amount) => {
        await exchange.connect(trader).deposit(0, { value: amount })
    }

    const getProtocolBalance = async () => {
        const fundInfo = await exchange.insuranceFundInfo()
        const protocolFee = await exchange.protocolInfo()
        return fundInfo.balance.add(fundInfo.liquidationRewardBalance).add(protocolFee)
    }

    const assertZerosum = async () => {
        let result = await getProtocolBalance()
        for (let i = 0; i < traders.length; i++) {
            result = result.add(await exchange.getTotalAccountValue(traders[i].address))
        }
        for (let i = 0; i < markets.length; i++) {
            const [base, accountValue] = await markets[i].getLockedLiquidityInfo()
            result = result.add(accountValue)
        }
        const ethBalance = await hre.ethers.provider.getBalance(exchange.address)
        expect(result).to.be.closeTo(ethBalance, epsilon)
    }

    const assertBaseZerosumByMarket = async market => {
        let result = BigNumber.from(0)
        for (let i = 0; i < traders.length; i++) {
            result = result.add(await exchange.getPositionShare(traders[i].address, market.address))
        }
        const [base, accountValue] = await market.getLockedLiquidityInfo()
        result = result.add(base)
        expect(result).to.be.closeTo(BigNumber.from(0), epsilon)
    }

    const assertBaseZerosum = async () => {
        for (let i = 0; i < markets.length; i++) {
            await assertBaseZerosumByMarket(markets[i])
        }
    }

    const setIndexPrice = async price => {
        await priceFeed.mock.getPrice.returns(price)
    }

    const setElapsed = async (sec, mine = false) => {
        const next = (await getTimestamp()) + 1000
        for (let i = 0; i < markets.length; i++) {
            const priceLimitInfo = await markets[i].priceLimitInfo()
            await markets[i].setPriceLimitInfo({
                ...priceLimitInfo,
                referenceTimestamp: BigNumber.from(next - sec),
            })

            const fundingInfo = await markets[i].fundingInfo()
            await markets[i].setFundingInfo({
                ...fundingInfo,
                prevIndexPriceTimestamp: BigNumber.from(next - sec),
            })
        }
        await setNextTimestamp(next, mine)
    }

    beforeEach(async () => {
        fixture = await loadFixture(
            createPerpdexExchangeFixture({
                isMarketAllowed: true,
                initPool: false,
            }),
        )
        exchange = fixture.perpdexExchange
        market = fixture.perpdexMarket
        owner = fixture.owner
        alice = fixture.alice
        bob = fixture.bob
        carol = fixture.carol
        markets = fixture.perpdexMarkets
        traders = [alice, bob, carol]
        priceFeed = fixture.priceFeed
    })

    describe("price limit", () => {
        beforeEach(async () => {
            await markets[0].connect(owner).setPriceLimitConfig({
                normalOrderRatio: 20e4,
                liquidationRatio: 40e4,
                emaNormalOrderRatio: 20e4,
                emaLiquidationRatio: 40e4,
                emaSec: 300,
            })

            await deposit(alice, PoolAmount)
            await deposit(bob, PoolAmount)
            await deposit(carol, 10)
            await setIndexPrice(X10_18.mul(4))
            await addLiquidity(bob, PoolAmount, PoolAmount.mul(4))
        })

        describe("same timestamp", () => {
            describe("long", () => {
                beforeEach(async () => {
                    await short(carol, 20) // will be liquidated
                    await setElapsed(1, true)

                    const amount = await maxLong(alice)
                    expect(amount).to.gt(epsilon)
                    await long(alice, amount)
                    await setElapsed(0, true)
                })

                it("long limited", async () => {
                    expect(await maxLong(alice)).to.lt(epsilon)
                    expect(await maxLong(bob)).to.lt(epsilon)
                })

                it("short not limited", async () => {
                    expect(await maxShort(alice)).to.gt(epsilon)
                    expect(await maxShort(bob)).to.gt(epsilon)
                })

                it("long liquidation not limited", async () => {
                    expect(await maxLongLiq(carol, alice)).to.gt(epsilon)
                })
            })

            describe("short", () => {
                beforeEach(async () => {
                    await long(carol, 20) // will be liquidated
                    await setElapsed(1, true)

                    const amount = await maxShort(alice)
                    expect(amount).to.gt(epsilon)
                    await short(alice, amount)
                    await setElapsed(0, true)
                })

                it("long not limited", async () => {
                    expect(await maxLong(alice)).to.gt(epsilon)
                    expect(await maxLong(bob)).to.gt(epsilon)
                })

                it("short limited", async () => {
                    expect(await maxShort(alice)).to.lt(epsilon)
                    expect(await maxShort(bob)).to.lt(epsilon)
                })

                it("short liquidation not limited", async () => {
                    expect(await maxShortLiq(carol, alice)).to.gt(epsilon)
                })
            })
        })

        describe("different timestamp", () => {
            describe("long", () => {
                beforeEach(async () => {
                    await short(carol, 20) // will be liquidated
                    await setElapsed(1, true)

                    const amount = await maxLong(alice)
                    expect(amount).to.gt(epsilon)
                    await long(alice, amount)
                    await setElapsed(1, true)
                })

                it("long not limited", async () => {
                    expect(await maxLong(alice)).to.gt(epsilon)
                    expect(await maxLong(bob)).to.gt(epsilon)
                })

                // TODO:
                it("long limited by ema", async () => {
                    // expect(await maxLong(alice)).to.lt(epsilon)
                    // expect(await maxLong(bob)).to.lt(epsilon)
                })

                it("short not limited", async () => {
                    expect(await maxShort(alice)).to.gt(epsilon)
                    expect(await maxShort(bob)).to.gt(epsilon)
                })

                it("long liquidation not limited", async () => {
                    expect(await maxLongLiq(carol, alice)).to.gt(epsilon)
                })
            })

            describe("short", () => {
                beforeEach(async () => {
                    await long(carol, 20) // will be liquidated
                    await setElapsed(1, true)

                    const amount = await maxShort(alice)
                    expect(amount).to.gt(epsilon)
                    await short(alice, amount)
                    await setElapsed(1, true)
                })

                it("long not limited", async () => {
                    expect(await maxLong(alice)).to.gt(epsilon)
                    expect(await maxLong(bob)).to.gt(epsilon)
                })

                it("short not limited", async () => {
                    expect(await maxShort(alice)).to.gt(epsilon)
                    expect(await maxShort(bob)).to.gt(epsilon)
                })

                it("short liquidation not limited", async () => {
                    expect(await maxShortLiq(carol, alice)).to.gt(epsilon)
                })
            })
        })
    })

    describe("consistency", () => {
        beforeEach(async () => {
            await exchange.connect(owner).setProtocolFeeRatio(1e4)
            await markets[0].connect(owner).setPriceLimitConfig({
                normalOrderRatio: 20e4,
                liquidationRatio: 40e4,
                emaNormalOrderRatio: 20e4,
                emaLiquidationRatio: 40e4,
                emaSec: 300,
            })
            await markets[0].connect(owner).setFundingMaxPremiumRatio(5e4)
            await markets[0].connect(owner).setFundingRolloverSec(3600)
            await markets[0].connect(owner).setFundingMaxElapsedSec(3600)

            await deposit(alice, PoolAmount)
            await deposit(bob, PoolAmount)
            await setIndexPrice(X10_18.mul(4))
            await addLiquidity(bob, PoolAmount, PoolAmount.mul(4))
        })

        describe("complex scenario", () => {
            beforeEach(async () => {
                const carolSize = await maxLong(carol)
                let amount = carolSize
                expect(amount).to.gt(epsilon)
                await deposit(carol, amount.div(2))
                await setIndexPrice(X10_18.mul(X10_18))
                await long(carol, amount) // will be liquidated
                await setIndexPrice(1)
                await setElapsed(3600, true)

                for (let i = 0; i < 5; i++) {
                    amount = await maxShort(alice)
                    expect(amount).to.gt(epsilon)
                    await short(alice, amount)
                    await setIndexPrice(X10_18.mul(X10_18))
                    await setElapsed(3600, true)
                }

                await shortLiq(carol, bob, carolSize)
                await setElapsed(3600, true)

                await removeLiquidity(bob, PoolAmount)
            })

            it("account value zero sum", async () => {
                await assertZerosum()
            })

            it("base zero sum", async () => {
                await assertBaseZerosum()
            })

            it("insurance fund profit", async () => {
                const fundInfo = await exchange.insuranceFundInfo()
                expect(fundInfo.balance).to.gt(epsilon)
                expect(fundInfo.liquidationRewardBalance).to.gt(epsilon)
            })

            it("protocol fee profit", async () => {
                const protocolFee = await exchange.protocolInfo()
                expect(protocolFee).to.gt(epsilon)
            })
        })
    })
})
