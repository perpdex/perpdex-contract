import { MockContract, smockit } from "@eth-optimism/smock"
import { ethers } from "hardhat"
import { PerpdexExchange, PerpdexMarket, TestERC20 } from "../../typechain"
import { ChainlinkPriceFeed } from "../../typechain/perp-oracle"

export interface PerpdexExchangeFixture {
    perpdexExchange: PerpdexExchange
    USDC: TestERC20
}

export function createPerpdexExchangeFixture(): () => Promise<PerpdexExchangeFixture> {
    return async (): Promise<PerpdexExchangeFixture> => {
        // deploy test tokens
        const tokenFactory = await ethers.getContractFactory("TestERC20")
        const USDC = (await tokenFactory.deploy()) as TestERC20
        await USDC.__TestERC20_init("TestUSDC", "USDC", 6)

        const perpdexExchangeFactory = await ethers.getContractFactory("PerpdexExchange")
        const perpdexExchange = (await perpdexExchangeFactory.deploy(USDC.address)) as PerpdexExchange

        return {
            perpdexExchange,
            USDC,
        }
    }
}
