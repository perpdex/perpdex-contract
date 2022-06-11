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

    beforeEach(async () => {
        fixture = await loadFixture(createPerpdexExchangeFixture())
        exchange = fixture.perpdexExchange
        market = fixture.perpdexMarket
        owner = fixture.owner
        alice = fixture.alice
    })

    describe("getTakerInfo", () => {
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

    describe("getMakerInfo", () => {
        it("ok", async () => {
            await exchange.setMakerInfo(alice.address, market.address, {
                liquidity: 3,
                cumBaseSharePerLiquidityX96: 4,
                cumQuotePerLiquidityX96: 5,
            })
            const makerInfo = await exchange.getMakerInfo(alice.address, market.address)
            expect(makerInfo.liquidity).to.eq(3)
            expect(makerInfo.cumBaseSharePerLiquidityX96).to.eq(4)
            expect(makerInfo.cumQuotePerLiquidityX96).to.eq(5)
        })
    })

    describe("getAccountMarkets", () => {
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
})
