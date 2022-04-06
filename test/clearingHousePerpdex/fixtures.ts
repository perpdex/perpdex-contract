import { MockContract, smockit } from "@eth-optimism/smock"
import { ethers } from "hardhat"
import {
    AccountBalancePerpdex,
    BaseToken,
    ClearingHousePerpdex,
    ClearingHouseConfig,
    ExchangePerpdex,
    InsuranceFund,
    MarketRegistryPerpdex,
    OrderBookUniswapV2,
    TestClearingHousePerpdex,
    TestERC20,
    TestExchangePerpdex,
    // TestUniswapV2Broker,
    UniswapV2Factory,
    UniswapV3Pool,
    Vault,
} from "../../typechain"
import { ChainlinkPriceFeed } from "../../typechain/perp-oracle"
import { QuoteToken } from "../../typechain/QuoteToken"
import { TestAccountBalancePerpdex } from "../../typechain/TestAccountBalancePerpdex"
import { createQuoteTokenFixture, token0Fixture, tokensFixture, uniswapV3FactoryFixture } from "../shared/fixtures"

export interface ClearingHousePerpdexFixture {
    clearingHouse: TestClearingHousePerpdex | ClearingHousePerpdex
    orderBook: OrderBookUniswapV2
    accountBalance: TestAccountBalancePerpdex | AccountBalancePerpdex
    marketRegistry: MarketRegistryPerpdex
    clearingHouseConfig: ClearingHouseConfig
    exchange: TestExchangePerpdex | ExchangePerpdex
    vault: Vault
    insuranceFund: InsuranceFund
    uniV2Factory: UniswapV2Factory
    // pool: UniswapV3Pool
    uniFeeTier: number
    USDC: TestERC20
    quoteToken: QuoteToken
    baseToken: BaseToken
    mockedBaseAggregator: MockContract
    baseToken2: BaseToken
    mockedBaseAggregator2: MockContract
    // pool2: UniswapV3Pool
}

// interface UniswapV2BrokerFixture {
//     uniswapV2Broker: TestUniswapV2Broker
// }

export enum BaseQuoteOrdering {
    BASE_0_QUOTE_1,
    BASE_1_QUOTE_0,
}

// caller of this function should ensure that (base, quote) = (token0, token1) is always true
export function createClearingHousePerpdexFixture(
    canMockTime: boolean = true,
    uniFeeTier = 10000, // 1%
): () => Promise<ClearingHousePerpdexFixture> {
    return async (): Promise<ClearingHousePerpdexFixture> => {
        // deploy test tokens
        const tokenFactory = await ethers.getContractFactory("TestERC20")
        const USDC = (await tokenFactory.deploy()) as TestERC20
        await USDC.__TestERC20_init("TestUSDC", "USDC", 6)

        let baseToken: BaseToken, quoteToken: QuoteToken, mockedBaseAggregator: MockContract
        const { token0, mockedAggregator0, token1 } = await tokensFixture()

        // we assume (base, quote) == (token0, token1)
        baseToken = token0
        quoteToken = token1
        mockedBaseAggregator = mockedAggregator0

        // deploy UniV2 factory
        const factoryFactory = await ethers.getContractFactory("UniswapV2Factory")
        const uniV2Factory = (await factoryFactory.deploy(ethers.constants.AddressZero)) as UniswapV2Factory

        const clearingHouseConfigFactory = await ethers.getContractFactory("ClearingHouseConfig")
        const clearingHouseConfig = (await clearingHouseConfigFactory.deploy()) as ClearingHouseConfig
        await clearingHouseConfig.initialize()

        // prepare uniswap factory
        // await uniV2Factory.createPool(baseToken.address, quoteToken.address, uniFeeTier)
        // const poolFactory = await ethers.getContractFactory("UniswapV3Pool")

        const marketRegistryFactory = await ethers.getContractFactory("MarketRegistryPerpdex")
        const marketRegistry = (await marketRegistryFactory.deploy()) as MarketRegistryPerpdex
        await marketRegistry.initialize(uniV2Factory.address, quoteToken.address)

        const orderBookFactory = await ethers.getContractFactory("OrderBookUniswapV2")
        const orderBook = (await orderBookFactory.deploy()) as OrderBookUniswapV2
        await orderBook.initialize(marketRegistry.address)

        let accountBalance
        let exchange
        if (canMockTime) {
            const accountBalanceFactory = await ethers.getContractFactory("TestAccountBalancePerpdex")
            accountBalance = (await accountBalanceFactory.deploy()) as TestAccountBalancePerpdex

            const exchangeFactory = await ethers.getContractFactory("TestExchangePerpdex")
            exchange = (await exchangeFactory.deploy()) as TestExchangePerpdex
        } else {
            const accountBalanceFactory = await ethers.getContractFactory("AccountBalancePerpdex")
            accountBalance = (await accountBalanceFactory.deploy()) as AccountBalancePerpdex

            const exchangeFactory = await ethers.getContractFactory("ExchangePerpdex")
            exchange = (await exchangeFactory.deploy()) as ExchangePerpdex
        }

        const insuranceFundFactory = await ethers.getContractFactory("InsuranceFund")
        const insuranceFund = (await insuranceFundFactory.deploy()) as InsuranceFund
        await insuranceFund.initialize(USDC.address)

        // deploy exchange
        await exchange.initialize(marketRegistry.address, orderBook.address, clearingHouseConfig.address)
        exchange.setAccountBalance(accountBalance.address)

        await orderBook.setExchange(exchange.address)

        await accountBalance.initialize(clearingHouseConfig.address, orderBook.address)

        const vaultFactory = await ethers.getContractFactory("Vault")
        const vault = (await vaultFactory.deploy()) as Vault
        await vault.initialize(
            insuranceFund.address,
            clearingHouseConfig.address,
            accountBalance.address,
            exchange.address,
        )
        await insuranceFund.setBorrower(vault.address)
        await accountBalance.setVault(vault.address)

        // deploy a pool
        // const poolAddr = await uniV2Factory.getPool(baseToken.address, quoteToken.address, uniFeeTier)
        // const pool = poolFactory.attach(poolAddr) as UniswapV3Pool
        // await baseToken.addWhitelist(pool.address)
        // await quoteToken.addWhitelist(pool.address)

        // deploy another pool
        const _token0Fixture = await token0Fixture(quoteToken.address)
        const baseToken2 = _token0Fixture.baseToken
        const mockedBaseAggregator2 = _token0Fixture.mockedAggregator
        // await uniV2Factory.createPool(baseToken2.address, quoteToken.address, uniFeeTier)
        // const pool2Addr = await uniV2Factory.getPool(baseToken2.address, quoteToken.address, uniFeeTier)
        // const pool2 = poolFactory.attach(pool2Addr) as UniswapV3Pool

        // await baseToken2.addWhitelist(pool2.address)
        // await quoteToken.addWhitelist(pool2.address)

        // deploy clearingHouse
        let clearingHouse: ClearingHousePerpdex | TestClearingHousePerpdex
        if (canMockTime) {
            const clearingHouseFactory = await ethers.getContractFactory("TestClearingHousePerpdex")
            const testClearingHouse = (await clearingHouseFactory.deploy()) as TestClearingHousePerpdex
            await testClearingHouse.__TestClearingHouse_init(
                clearingHouseConfig.address,
                vault.address,
                quoteToken.address,
                uniV2Factory.address,
                exchange.address,
                accountBalance.address,
                insuranceFund.address,
            )
            clearingHouse = testClearingHouse
        } else {
            const clearingHouseFactory = await ethers.getContractFactory("ClearingHousePerpdex")
            clearingHouse = (await clearingHouseFactory.deploy()) as ClearingHousePerpdex
            await clearingHouse.initialize(
                clearingHouseConfig.address,
                vault.address,
                quoteToken.address,
                uniV2Factory.address,
                exchange.address,
                accountBalance.address,
                insuranceFund.address,
            )
        }

        await clearingHouseConfig.setSettlementTokenBalanceCap(ethers.constants.MaxUint256)
        await quoteToken.mintMaximumTo(clearingHouse.address)
        await baseToken.mintMaximumTo(clearingHouse.address)
        await baseToken2.mintMaximumTo(clearingHouse.address)
        await quoteToken.addWhitelist(clearingHouse.address)
        await baseToken.addWhitelist(clearingHouse.address)
        await baseToken2.addWhitelist(clearingHouse.address)
        await marketRegistry.setClearingHouse(clearingHouse.address)
        await orderBook.setClearingHouse(clearingHouse.address)
        await exchange.setClearingHouse(clearingHouse.address)
        await accountBalance.setClearingHouse(clearingHouse.address)
        await vault.setClearingHouse(clearingHouse.address)

        return {
            clearingHouse,
            orderBook,
            accountBalance,
            marketRegistry,
            clearingHouseConfig,
            exchange,
            vault,
            insuranceFund,
            uniV2Factory,
            // pool,
            uniFeeTier,
            USDC,
            quoteToken,
            baseToken,
            mockedBaseAggregator,
            baseToken2,
            mockedBaseAggregator2,
            // pool2,
        }
    }
}

// export async function uniswapV3BrokerFixture(): Promise<UniswapV2BrokerFixture> {
//     const factory = await uniswapV3FactoryFixture()
//     const uniswapV3BrokerFactory = await ethers.getContractFactory("TestUniswapV2Broker")
//     const uniswapV2Broker = (await uniswapV3BrokerFactory.deploy()) as TestUniswapV2Broker
//     await uniswapV2Broker.initialize(factory.address)
//     return { uniswapV2Broker }
// }

interface MockedClearingHouseFixture {
    clearingHouse: ClearingHousePerpdex
    clearingHouseConfig: ClearingHouseConfig
    exchange: ExchangePerpdex
    mockedUniV2Factory: MockContract
    mockedVault: MockContract
    mockedQuoteToken: MockContract
    mockedUSDC: MockContract
    mockedBaseToken: MockContract
    mockedExchange: MockContract
    mockedInsuranceFund: MockContract
    mockedAccountBalance: MockContract
    mockedMarketRegistry: MockContract
}

export const ADDR_GREATER_THAN = true
export const ADDR_LESS_THAN = false
export async function mockedBaseTokenTo(longerThan: boolean, targetAddr: string): Promise<MockContract> {
    // deployer ensure base token is always smaller than quote in order to achieve base=token0 and quote=token1
    let mockedToken: MockContract
    while (
        !mockedToken ||
        (longerThan
            ? mockedToken.address.toLowerCase() <= targetAddr.toLowerCase()
            : mockedToken.address.toLowerCase() >= targetAddr.toLowerCase())
    ) {
        const aggregatorFactory = await ethers.getContractFactory("TestAggregatorV3")
        const aggregator = await aggregatorFactory.deploy()
        const mockedAggregator = await smockit(aggregator)

        const chainlinkPriceFeedFactory = await ethers.getContractFactory("ChainlinkPriceFeed")
        const chainlinkPriceFeed = (await chainlinkPriceFeedFactory.deploy(
            mockedAggregator.address,
            15 * 60,
        )) as ChainlinkPriceFeed

        const baseTokenFactory = await ethers.getContractFactory("BaseToken")
        const token = (await baseTokenFactory.deploy()) as BaseToken
        await token.initialize("Test", "Test", chainlinkPriceFeed.address)
        mockedToken = await smockit(token)
        mockedToken.smocked.decimals.will.return.with(async () => {
            return 18
        })
    }
    return mockedToken
}

export async function mockedClearingHouseFixture(): Promise<MockedClearingHouseFixture> {
    const token1 = await createQuoteTokenFixture("RandomVirtualToken", "RVT")()

    // deploy test tokens
    const tokenFactory = await ethers.getContractFactory("TestERC20")
    const USDC = (await tokenFactory.deploy()) as TestERC20
    await USDC.__TestERC20_init("TestUSDC", "USDC", 6)

    const insuranceFundFactory = await ethers.getContractFactory("InsuranceFund")
    const insuranceFund = (await insuranceFundFactory.deploy()) as InsuranceFund
    const mockedInsuranceFund = await smockit(insuranceFund)

    const vaultFactory = await ethers.getContractFactory("Vault")
    const vault = (await vaultFactory.deploy()) as Vault
    const mockedVault = await smockit(vault)

    const mockedUSDC = await smockit(USDC)
    const mockedQuoteToken = await smockit(token1)
    mockedQuoteToken.smocked.decimals.will.return.with(async () => {
        return 18
    })

    // deploy UniV2 factory
    const factoryFactory = await ethers.getContractFactory("UniswapV2Factory")
    const uniV2Factory = (await factoryFactory.deploy(ethers.constants.AddressZero)) as UniswapV2Factory
    const mockedUniV2Factory = await smockit(uniV2Factory)

    const clearingHouseConfigFactory = await ethers.getContractFactory("ClearingHouseConfig")
    const clearingHouseConfig = (await clearingHouseConfigFactory.deploy()) as ClearingHouseConfig

    const marketRegistryFactory = await ethers.getContractFactory("MarketRegistryPerpdex")
    const marketRegistry = (await marketRegistryFactory.deploy()) as MarketRegistryPerpdex
    await marketRegistry.initialize(mockedUniV2Factory.address, mockedQuoteToken.address)
    const mockedMarketRegistry = await smockit(marketRegistry)
    const orderBookFactory = await ethers.getContractFactory("OrderBookUniswapV2")
    const orderBook = (await orderBookFactory.deploy()) as OrderBookUniswapV2
    await orderBook.initialize(marketRegistry.address)
    const mockedOrderBook = await smockit(orderBook)

    const exchangeFactory = await ethers.getContractFactory("ExchangePerpdex")
    const exchange = (await exchangeFactory.deploy()) as ExchangePerpdex
    await exchange.initialize(mockedMarketRegistry.address, mockedOrderBook.address, clearingHouseConfig.address)
    const mockedExchange = await smockit(exchange)

    const accountBalanceFactory = await ethers.getContractFactory("AccountBalancePerpdex")
    const accountBalance = (await accountBalanceFactory.deploy()) as AccountBalancePerpdex
    const mockedAccountBalance = await smockit(accountBalance)

    // deployer ensure base token is always smaller than quote in order to achieve base=token0 and quote=token1
    const mockedBaseToken = await mockedBaseTokenTo(ADDR_LESS_THAN, mockedQuoteToken.address)

    mockedExchange.smocked.getOrderBook.will.return.with(mockedOrderBook.address)

    // deploy clearingHouse
    const clearingHouseFactory = await ethers.getContractFactory("ClearingHousePerpdex")
    const clearingHouse = (await clearingHouseFactory.deploy()) as ClearingHousePerpdex
    await clearingHouse.initialize(
        clearingHouseConfig.address,
        mockedVault.address,
        mockedQuoteToken.address,
        mockedUniV2Factory.address,
        mockedExchange.address,
        mockedAccountBalance.address,
        insuranceFund.address,
    )
    return {
        clearingHouse,
        clearingHouseConfig,
        exchange,
        mockedExchange,
        mockedUniV2Factory,
        mockedVault,
        mockedQuoteToken,
        mockedUSDC,
        mockedBaseToken,
        mockedInsuranceFund,
        mockedAccountBalance,
        mockedMarketRegistry,
    }
}
