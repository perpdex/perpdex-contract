import { ethers, waffle } from "hardhat"
import { TestPerpdexMarket } from "../../typechain"
import IPerpdexPriceFeedJson from "../../artifacts/contracts/interface/IPerpdexPriceFeed.sol/IPerpdexPriceFeed.json"
import { MockContract } from "ethereum-waffle"
import { Wallet } from "ethers"

interface PerpdexMarketFixture {
    perpdexMarket: TestPerpdexMarket
    priceFeed: MockContract
    owner: Wallet
    alice: Wallet
    bob: Wallet
    exchange: Wallet
}

export function createPerpdexMarketFixture(): (wallets, provider) => Promise<PerpdexMarketFixture> {
    return async ([owner, alice, bob, exchange], provider): Promise<PerpdexMarketFixture> => {
        const priceFeed = await waffle.deployMockContract(owner, IPerpdexPriceFeedJson.abi)
        await priceFeed.mock.getPrice.returns(1)

        const perpdexMarketFactory = await ethers.getContractFactory("TestPerpdexMarket")
        const perpdexMarket = (await perpdexMarketFactory.deploy(
            "USD",
            exchange.address,
            priceFeed.address,
            ethers.constants.AddressZero,
        )) as TestPerpdexMarket

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
