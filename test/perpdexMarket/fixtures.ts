import { ethers, waffle } from "hardhat"
import { PerpdexExchange, PerpdexMarket, IPerpdexPriceFeed, TestWETH9 } from "../../typechain"
import { ChainlinkPriceFeed } from "../../typechain/perp-oracle"
import IPerpdexPriceFeedJson from "../../artifacts/contracts/interface/IPerpdexPriceFeed.sol/IPerpdexPriceFeed.json"
import { MockContract } from "ethereum-waffle"
import { Wallet } from "ethers"

export interface PerpdexMarketFixture {
    perpdexMarket: PerpdexMarket
    priceFeed: MockContract
    owner: Wallet
    alice: Wallet
    bob: Wallet
    exchange: Wallet
}

export function createPerpdexMarketFixture(): (wallets, provider) => Promise<PerpdexMarketFixture> {
    return async ([owner, alice, bob, exchange], provider): Promise<PerpdexMarketFixture> => {
        const priceFeed = await waffle.deployMockContract(owner, IPerpdexPriceFeedJson.abi)

        const perpdexMarketFactory = await ethers.getContractFactory("PerpdexMarket")
        const perpdexMarket = (await perpdexMarketFactory.deploy(
            "USD",
            exchange.address,
            priceFeed.address,
        )) as PerpdexMarket

        return {
            perpdexMarket,
            priceFeed,
            owner,
            alice,
            bob,
            exchange,
        }
    }
}
