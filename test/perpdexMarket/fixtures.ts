import { ethers, waffle } from "hardhat"
import { PerpdexMarket } from "../../typechain"
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
