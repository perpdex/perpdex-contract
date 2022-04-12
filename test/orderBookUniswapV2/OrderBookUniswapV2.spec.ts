import { parseEther } from "@ethersproject/units"
import { expect } from "chai"
import { parseUnits } from "ethers/lib/utils"
import { ethers, waffle } from "hardhat"
import {
    AccountBalance,
    BaseToken,
    ExchangePerpdex,
    MarketRegistryPerpdex,
    OrderBookUniswapV2,
    QuoteToken,
    TestClearingHousePerpdex,
    TestERC20,
    UniswapV3Pool,
    Vault,
} from "../../typechain"
import { ClearingHousePerpdexFixture, createClearingHousePerpdexFixture } from "../clearingHousePerpdex/fixtures"
import { initAndAddPool } from "../helper/marketHelperPerpdex"
import { getMaxTick, getMaxTickRange, getMinTick } from "../helper/number"
import { deposit } from "../helper/token"
import { encodePriceSqrt } from "../shared/utilities"
import { BigNumber } from "ethers"

describe("OrderBookUniswapV2", () => {
    const [admin, alice, bob] = waffle.provider.getWallets()
    const loadFixture: ReturnType<typeof waffle.createFixtureLoader> = waffle.createFixtureLoader([admin])
    let fixture: ClearingHousePerpdexFixture
    let clearingHouse: TestClearingHousePerpdex
    let marketRegistry: MarketRegistryPerpdex
    let exchange: ExchangePerpdex
    let orderBook: OrderBookUniswapV2
    let accountBalance: AccountBalance
    let vault: Vault
    let collateral: TestERC20
    let baseToken: BaseToken
    let baseToken2: BaseToken
    let quoteToken: QuoteToken
    let collateralDecimals: number

    beforeEach(async () => {
        fixture = await loadFixture(createClearingHousePerpdexFixture())
        clearingHouse = fixture.clearingHouse as TestClearingHousePerpdex
        orderBook = fixture.orderBook
        exchange = fixture.exchange
        accountBalance = fixture.accountBalance
        marketRegistry = fixture.marketRegistry
        vault = fixture.vault
        collateral = fixture.USDC
        baseToken = fixture.baseToken
        baseToken2 = fixture.baseToken2
        quoteToken = fixture.quoteToken
        collateralDecimals = await collateral.decimals()

        // alice
        await collateral.mint(alice.address, parseUnits("40000", collateralDecimals))
        await deposit(alice, vault, 40000, collateral)
    })

    describe("getTotalTokenAmountInPoolAndPendingFee()", () => {
        beforeEach(async () => {
            await initAndAddPool(
                fixture,
                baseToken.address,
                0,
                10000,
                // set maxTickCrossed as maximum tick range of pool by default, that means there is no over price when swap
                BigNumber.from("2").pow(96),
            )
        })

        it("empty", async () => {
            const baseRes = await orderBook.getTotalTokenAmountInPoolAndPendingFee(
                alice.address,
                baseToken.address,
                true,
            )
            const quoteRes = await orderBook.getTotalTokenAmountInPoolAndPendingFee(
                alice.address,
                baseToken.address,
                false,
            )

            expect(baseRes).be.deep.eq([BigNumber.from(0), BigNumber.from(0)])
            expect(quoteRes).be.deep.eq([BigNumber.from(0), BigNumber.from(0)])
        })

        it("alice add liquidity", async () => {
            // alice add liquidity (baseToken)
            await clearingHouse.connect(alice).addLiquidity({
                baseToken: baseToken.address,
                base: parseEther("1"),
                quote: parseEther("2"),
                minBase: 0,
                minQuote: 0,
                deadline: ethers.constants.MaxUint256,
            })

            const baseRes = await orderBook.getTotalTokenAmountInPoolAndPendingFee(
                alice.address,
                baseToken.address,
                true,
            )
            const quoteRes = await orderBook.getTotalTokenAmountInPoolAndPendingFee(
                alice.address,
                baseToken.address,
                false,
            )

            expect(baseRes).be.deep.eq([BigNumber.from("999999999999999292"), BigNumber.from(0)])
            expect(quoteRes).be.deep.eq([BigNumber.from("1999999999999998585"), BigNumber.from(0)])
        })
    })
})
