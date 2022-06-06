import { ethers, waffle } from "hardhat"
import { TestPriceLimitLibrary } from "../../typechain"

interface PriceLimitLibraryFixture {
    priceLimitLibrary: TestPriceLimitLibrary
}

export function createPriceLimitLibraryFixture(): (wallets, provider) => Promise<PriceLimitLibraryFixture> {
    return async ([owner], provider): Promise<PriceLimitLibraryFixture> => {
        const factory = await ethers.getContractFactory("TestPriceLimitLibrary")
        const priceLimitLibrary = (await factory.deploy()) as TestPriceLimitLibrary

        return {
            priceLimitLibrary,
        }
    }
}
