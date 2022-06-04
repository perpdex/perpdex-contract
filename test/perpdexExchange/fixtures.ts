import { MockContract, smockit } from "@eth-optimism/smock"
import { ethers, waffle } from "hardhat"
import { TestPerpdexExchange, TestPerpdexMarket, TestERC20 } from "../../typechain"
import { BigNumber, Wallet } from "ethers"
import IPerpdexPriceFeedJson from "../../artifacts/contracts/interface/IPerpdexPriceFeed.sol/IPerpdexPriceFeed.json"

export interface PerpdexExchangeFixture {
    perpdexExchange: TestPerpdexExchange
    perpdexMarket: TestPerpdexMarket
    USDC: TestERC20
    owner: Wallet
    alice: Wallet
}

interface Params {
    linear: Boolean
}

export function createPerpdexExchangeFixture(
    params: Params = { linear: false },
): (wallets, provider) => Promise<PerpdexExchangeFixture> {
    return async ([owner, alice], provider): Promise<PerpdexExchangeFixture> => {
        let settlementToken = hre.ethers.constants.AddressZero
        let USDC

        if (params.linear) {
            const tokenFactory = await ethers.getContractFactory("TestERC20")
            USDC = (await tokenFactory.deploy("TestUSDC", "USDC", 6)) as TestERC20
            settlementToken = USDC.address
        }

        const perpdexExchangeFactory = await ethers.getContractFactory("TestPerpdexExchange")
        const perpdexExchange = (await perpdexExchangeFactory.deploy(settlementToken)) as TestPerpdexExchange

        const priceFeed = await waffle.deployMockContract(owner, IPerpdexPriceFeedJson.abi)
        await priceFeed.mock.getPrice.returns(BigNumber.from(10).pow(18))
        await priceFeed.mock.decimals.returns(18)

        const perpdexMarketFactory = await ethers.getContractFactory("TestPerpdexMarket")
        const perpdexMarket = (await perpdexMarketFactory.deploy(
            "USD",
            perpdexExchange.address,
            priceFeed.address,
            ethers.constants.AddressZero,
        )) as TestPerpdexMarket

        await perpdexMarket.connect(owner).setPoolFeeRatio(0)
        await perpdexMarket.connect(owner).setFundingMaxPremiumRatio(0)

        return {
            perpdexExchange,
            perpdexMarket,
            USDC,
            owner,
            alice,
        }
    }
}
