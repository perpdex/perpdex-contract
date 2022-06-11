import { expect } from "chai"
import { waffle } from "hardhat"
import { TestPerpdexExchange, TestPerpdexMarket } from "../../typechain"
import { createPerpdexExchangeFixture } from "./fixtures"
import { BigNumber, Wallet } from "ethers"

describe("PerpdexExchange updateMarkets", () => {
    let loadFixture = waffle.createFixtureLoader(waffle.provider.getWallets())
    let fixture

    let exchange: TestPerpdexExchange
    let market: TestPerpdexMarket
    let owner: Wallet
    let alice: Wallet
    let deadline = BigNumber.from(2).pow(96)

    const long = async amount => {
        await exchange.connect(alice).trade({
            trader: alice.address,
            market: market.address,
            isBaseToQuote: false,
            isExactInput: false,
            amount: amount,
            oppositeAmountBound: 10 * amount,
            deadline: deadline,
        })
    }

    const short = async amount => {
        await exchange.connect(alice).trade({
            trader: alice.address,
            market: market.address,
            isBaseToQuote: true,
            isExactInput: true,
            amount: amount,
            oppositeAmountBound: 0,
            deadline: deadline,
        })
    }

    const addLiquidity = async (base, quote) => {
        await exchange.connect(alice).addLiquidity({
            market: market.address,
            base: base,
            quote: quote,
            minBase: 0,
            minQuote: 0,
            deadline: deadline,
        })
    }

    const removeLiquidity = async liquidity => {
        await exchange.connect(alice).removeLiquidity({
            trader: alice.address,
            market: market.address,
            liquidity: liquidity,
            minBase: 0,
            minQuote: 0,
            deadline: deadline,
        })
    }

    beforeEach(async () => {
        fixture = await loadFixture(createPerpdexExchangeFixture())
        exchange = fixture.perpdexExchange
        market = fixture.perpdexMarket
        owner = fixture.owner
        alice = fixture.alice

        await exchange.connect(owner).setIsMarketAllowed(market.address, true)

        await exchange.setAccountInfo(
            alice.address,
            {
                collateralBalance: 10000,
            },
            [],
        )

        await exchange.setAccountInfo(
            owner.address,
            {
                collateralBalance: 10000,
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

    describe("updateMarkets", () => {
        it("taker", async () => {
            await long(100)
            const markets = await exchange.getAccountMarkets(alice.address)
            expect(markets).to.deep.eq([market.address])

            await short(50)
            const markets2 = await exchange.getAccountMarkets(alice.address)
            expect(markets2).to.deep.eq([market.address])

            await short(50)
            const markets3 = await exchange.getAccountMarkets(alice.address)
            expect(markets3).to.deep.eq([])

            await short(100)
            const markets4 = await exchange.getAccountMarkets(alice.address)
            expect(markets4).to.deep.eq([market.address])

            await long(100)
            const markets5 = await exchange.getAccountMarkets(alice.address)
            expect(markets5).to.deep.eq([])
        })

        it("maker", async () => {
            await addLiquidity(100, 100)
            const markets = await exchange.getAccountMarkets(alice.address)
            expect(markets).to.deep.eq([market.address])

            await removeLiquidity(50)
            const markets2 = await exchange.getAccountMarkets(alice.address)
            expect(markets2).to.deep.eq([market.address])

            await removeLiquidity(50)
            const markets3 = await exchange.getAccountMarkets(alice.address)
            expect(markets3).to.deep.eq([])
        })
    })
})
