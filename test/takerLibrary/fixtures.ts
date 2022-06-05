import { ethers, waffle } from "hardhat"
import { TestTakerLibrary } from "../../typechain"

interface TakerLibraryFixture {
    takerLibrary: TestTakerLibrary
}

export function createTakerLibraryFixture(): (wallets, provider) => Promise<TakerLibraryFixture> {
    return async ([owner], provider): Promise<TakerLibraryFixture> => {
        const factory = await ethers.getContractFactory("TestTakerLibrary")
        const takerLibrary = (await factory.deploy()) as TestTakerLibrary

        return {
            takerLibrary,
        }
    }
}
