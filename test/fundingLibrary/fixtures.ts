import { ethers, waffle } from "hardhat"
import { TestFundingLibrary } from "../../typechain"
import IPerpdexPriceFeedJson from "../../artifacts/contracts/interfaces/IPerpdexPriceFeed.sol/IPerpdexPriceFeed.json"
import { MockContract } from "ethereum-waffle"

interface FundingLibraryFixture {
    fundingLibrary: TestFundingLibrary
    priceFeedBase: MockContract
    priceFeedQuote: MockContract
}

export function createFundingLibraryFixture(): (wallets, provider) => Promise<FundingLibraryFixture> {
    return async ([owner], provider): Promise<FundingLibraryFixture> => {
        const factory = await ethers.getContractFactory("TestFundingLibrary")
        const fundingLibrary = (await factory.deploy()) as TestFundingLibrary

        const priceFeedBase = await waffle.deployMockContract(owner, IPerpdexPriceFeedJson.abi)
        const priceFeedQuote = await waffle.deployMockContract(owner, IPerpdexPriceFeedJson.abi)

        await priceFeedBase.mock.decimals.returns(18)
        await priceFeedQuote.mock.decimals.returns(18)

        return {
            fundingLibrary,
            priceFeedBase,
            priceFeedQuote,
        }
    }
}
