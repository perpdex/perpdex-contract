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
    QuoteToken,
    UniswapV2Factory,
    Vault,
} from "../typechain"
import { ChainlinkPriceFeed } from "../typechain/perp-oracle"
import { config, safeVerify } from "./common"

const quoteTokenName = "QuoteToken"
const quoteTokenSymbol = "QUOTE"

const baseTokenName = "BaseTokenEth"
const baseTokenSymbol = "BASEETH"

async function main() {
    console.log(config)

    const chainlinkPriceFeedFactory = await ethers.getContractFactory("ChainlinkPriceFeed")
    const chainlinkPriceFeed = (await chainlinkPriceFeedFactory.deploy(
        config.chainlinkDataFeed.ethUsd,
        15 * 60,
    )) as ChainlinkPriceFeed
    await chainlinkPriceFeed.deployed()
    await chainlinkPriceFeed.update()
    console.log("chainlinkPriceFeed " + chainlinkPriceFeed.address)

    const quoteTokenFactory = await ethers.getContractFactory("QuoteToken")
    const quoteToken = (await quoteTokenFactory.deploy()) as QuoteToken
    await quoteToken.deployed()
    await quoteToken.initialize(quoteTokenName, quoteTokenSymbol)
    console.log("quoteToken " + quoteToken.address)

    const baseTokenFactory = await ethers.getContractFactory("BaseToken")
    const baseToken = (await baseTokenFactory.deploy()) as BaseToken
    await baseToken.deployed()
    await baseToken.initialize(baseTokenName, baseTokenSymbol, chainlinkPriceFeed.address)
    console.log("baseToken " + baseToken.address)

    const factoryFactory = await ethers.getContractFactory("UniswapV2Factory")
    const uniV2Factory = (await factoryFactory.deploy(ethers.constants.AddressZero)) as UniswapV2Factory
    await uniV2Factory.deployed()
    console.log("uniV2Factory " + uniV2Factory.address)

    const clearingHouseConfigFactory = await ethers.getContractFactory("ClearingHouseConfig")
    const clearingHouseConfig = (await clearingHouseConfigFactory.deploy()) as ClearingHouseConfig
    await clearingHouseConfig.deployed()
    await clearingHouseConfig.initialize()
    console.log("clearingHouseConfig " + clearingHouseConfig.address)

    const marketRegistryFactory = await ethers.getContractFactory("MarketRegistryPerpdex")
    const marketRegistry = (await marketRegistryFactory.deploy()) as MarketRegistryPerpdex
    await marketRegistry.deployed()
    await marketRegistry.initialize(uniV2Factory.address, quoteToken.address)
    console.log("marketRegistry " + marketRegistry.address)

    const orderBookFactory = await ethers.getContractFactory("OrderBookUniswapV2")
    const orderBook = (await orderBookFactory.deploy()) as OrderBookUniswapV2
    await orderBook.deployed()
    await orderBook.initialize(marketRegistry.address)
    console.log("orderBook " + orderBook.address)

    const accountBalanceFactory = await ethers.getContractFactory("AccountBalancePerpdex")
    const accountBalance = (await accountBalanceFactory.deploy()) as AccountBalancePerpdex
    await accountBalance.deployed()
    await accountBalance.initialize(clearingHouseConfig.address, orderBook.address)
    console.log("accountBalance " + accountBalance.address)

    const exchangeFactory = await ethers.getContractFactory("ExchangePerpdex")
    const exchange = (await exchangeFactory.deploy()) as ExchangePerpdex
    await exchange.deployed()
    await exchange.initialize(marketRegistry.address, orderBook.address, clearingHouseConfig.address)
    await orderBook.setExchange(exchange.address)
    console.log("exchange " + exchange.address)

    const insuranceFundFactory = await ethers.getContractFactory("InsuranceFund")
    const insuranceFund = (await insuranceFundFactory.deploy()) as InsuranceFund
    await insuranceFund.deployed()
    await insuranceFund.initialize(config.usdc)
    console.log("insuranceFund " + insuranceFund.address)

    const vaultFactory = await ethers.getContractFactory("Vault")
    const vault = (await vaultFactory.deploy()) as Vault
    await vault.deployed()
    await vault.initialize(insuranceFund.address, clearingHouseConfig.address, accountBalance.address, exchange.address)
    await insuranceFund.setBorrower(vault.address)
    await accountBalance.setVault(vault.address)
    console.log("vault " + vault.address)

    const clearingHouseFactory = await ethers.getContractFactory("ClearingHousePerpdex")
    const clearingHouse = (await clearingHouseFactory.deploy()) as ClearingHousePerpdex
    await clearingHouse.deployed()
    await clearingHouse.initialize(
        clearingHouseConfig.address,
        vault.address,
        quoteToken.address,
        uniV2Factory.address,
        exchange.address,
        accountBalance.address,
        insuranceFund.address,
    )
    console.log("clearingHouse " + clearingHouse.address)

    await clearingHouseConfig.setSettlementTokenBalanceCap(ethers.constants.MaxUint256)
    await quoteToken.mintMaximumTo(clearingHouse.address)
    await baseToken.mintMaximumTo(clearingHouse.address)
    // await quoteToken.addWhitelist(clearingHouse.address)
    // await baseToken.addWhitelist(clearingHouse.address)
    await marketRegistry.setClearingHouse(clearingHouse.address)
    await orderBook.setClearingHouse(clearingHouse.address)
    await exchange.setClearingHouse(clearingHouse.address)
    await accountBalance.setClearingHouse(clearingHouse.address)
    await vault.setClearingHouse(clearingHouse.address)

    // TODO: Investigate an issue where setAccountBalance fails only with rinkeby
    console.log("call setAccountBalance")
    await exchange.setAccountBalance(accountBalance.address)

    // TODO: Investigate an issue where setMaxPriceRocWithinBlock fails only with rinkeby
    console.log("call setMaxPriceRocWithinBlock")
    await exchange.setMaxPriceRocWithinBlock(baseToken.address, ethers.BigNumber.from(2).pow(95))

    console.log("verify")

    await safeVerify(chainlinkPriceFeed.address, [config.chainlinkDataFeed.ethUsd, 15 * 60])
    await safeVerify(quoteToken.address, [])
    await safeVerify(baseToken.address, [])
    await safeVerify(uniV2Factory.address, [ethers.constants.AddressZero])
    await safeVerify(clearingHouseConfig.address, [])
    await safeVerify(marketRegistry.address, [])
    await safeVerify(orderBook.address, [])
    await safeVerify(accountBalance.address, [])
    await safeVerify(exchange.address, [])
    await safeVerify(insuranceFund.address, [])
    await safeVerify(vault.address, [])
    await safeVerify(clearingHouse.address, [])

    console.log("deploy finished")
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    })
