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

const hre = require("hardhat")

const quoteTokenName = "QuoteToken"
const quoteTokenSymbol = "QUOTE"

const baseTokenName = "BaseTokenEth"
const baseTokenSymbol = "BASEETH"

const config = {
    localhost: {
        // eth mainnet fork for test
        weth: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
        usdc: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        chainlinkDataFeed: {
            ethUsd: "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419",
        },
    },
    rinkeby: {
        weth: "0xc778417E063141139Fce010982780140Aa0cD5Ab",
        usdc: "0xeb8f08a975Ab53E34D8a0330E0D34de942C95926",
        chainlinkDataFeed: {
            ethUsd: "0x8A753747A1Fa494EC906cE90E9f37563A8AF630e",
        },
    },
    mumbai: {
        weth: "0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa",
        usdc: "0xe11A86849d99F524cAC3E7A0Ec1241828e332C62",
        chainlinkDataFeed: {
            ethUsd: "0x0715A7794a1dc8e42615F059dD6e406A6594651A",
        },
    },
    fuji: {
        weth: "0xd00ae08403B9bbb9124bB305C09058E32C39A48c", // WAVAX
        usdc: "0x5425890298aed601595a70AB815c96711a31Bc65",
        chainlinkDataFeed: {
            ethUsd: "0x5498BB86BC934c8D34FDA08E81D444153d0D06aD", // AVAX/USD
        },
    },
}[hre.network.name]

async function main() {
    console.log(config)

    const chainlinkPriceFeedFactory = await ethers.getContractFactory("ChainlinkPriceFeed")
    const chainlinkPriceFeed = (await chainlinkPriceFeedFactory.deploy(
        config.chainlinkDataFeed.ethUsd,
        15 * 60,
    )) as ChainlinkPriceFeed
    await chainlinkPriceFeed.deployed()
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

    console.log("deploy finished")
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    })
