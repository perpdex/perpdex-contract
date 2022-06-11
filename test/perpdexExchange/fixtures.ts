import { ethers, waffle } from "hardhat"
import { TestPerpdexExchange, TestPerpdexMarket, TestERC20 } from "../../typechain"
import { BigNumber, Wallet } from "ethers"
import IPerpdexPriceFeedJson from "../../artifacts/contracts/interface/IPerpdexPriceFeed.sol/IPerpdexPriceFeed.json"
import { MockContract } from "ethereum-waffle"

export interface PerpdexExchangeFixture {
    perpdexExchange: TestPerpdexExchange
    perpdexMarket: TestPerpdexMarket
    perpdexMarkets: TestPerpdexMarket[]
    USDC: TestERC20
    owner: Wallet
    alice: Wallet
    bob: Wallet
    priceFeed: MockContract
    priceFeeds: MockContract[]
}

interface Params {
    linear?: Boolean
    isMarketAllowed?: Boolean
    initPool?: Boolean
}

const Q96 = BigNumber.from(2).pow(96)

export function createPerpdexExchangeFixture(
    params: Params = { linear: false, isMarketAllowed: false, initPool: false },
): (wallets, provider) => Promise<PerpdexExchangeFixture> {
    return async ([owner, alice, bob], provider): Promise<PerpdexExchangeFixture> => {
        let settlementToken = hre.ethers.constants.AddressZero
        let USDC

        if (params.linear) {
            const tokenFactory = await ethers.getContractFactory("TestERC20")
            USDC = (await tokenFactory.deploy("TestUSDC", "USDC", 6)) as TestERC20
            settlementToken = USDC.address
        }

        const perpdexExchangeFactory = await ethers.getContractFactory("TestPerpdexExchange")
        const perpdexExchange = (await perpdexExchangeFactory.deploy(settlementToken)) as TestPerpdexExchange

        const perpdexMarketFactory = await ethers.getContractFactory("TestPerpdexMarket")
        const perpdexMarkets = []
        const priceFeeds = []
        for (let i = 0; i < 3; i++) {
            priceFeeds[i] = await waffle.deployMockContract(owner, IPerpdexPriceFeedJson.abi)
            await priceFeeds[i].mock.getPrice.returns(BigNumber.from(10).pow(18))
            await priceFeeds[i].mock.decimals.returns(18)

            perpdexMarkets[i] = (await perpdexMarketFactory.deploy(
                "USD",
                perpdexExchange.address,
                priceFeeds[i].address,
                ethers.constants.AddressZero,
            )) as TestPerpdexMarket

            await perpdexMarkets[i].connect(owner).setPoolFeeRatio(0)
            await perpdexMarkets[i].connect(owner).setFundingMaxPremiumRatio(0)

            if (params.isMarketAllowed) {
                await perpdexExchange.connect(owner).setIsMarketAllowed(perpdexMarkets[i].address, true)
            }

            if (params.initPool) {
                await perpdexMarkets[i].setPoolInfo({
                    base: 10000,
                    quote: 10000,
                    totalLiquidity: 10000,
                    cumBasePerLiquidityX96: 0,
                    cumQuotePerLiquidityX96: 0,
                    baseBalancePerShareX96: Q96,
                })
            }
        }

        const perpdexMarket = perpdexMarkets[0]
        const priceFeed = priceFeeds[0]

        return {
            perpdexExchange,
            perpdexMarket,
            perpdexMarkets,
            USDC,
            owner,
            alice,
            bob,
            priceFeed,
            priceFeeds,
        }
    }
}
