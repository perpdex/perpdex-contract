import { ethers, waffle } from "hardhat"
import { TestPoolLibrary } from "../../typechain"

interface PoolLibraryFixture {
    poolLibrary: TestPoolLibrary
}

export function createPoolLibraryFixture(): (wallets, provider) => Promise<PoolLibraryFixture> {
    return async ([owner], provider): Promise<PoolLibraryFixture> => {
        const factory = await ethers.getContractFactory("TestPoolLibrary")
        const poolLibrary = (await factory.deploy()) as TestPoolLibrary

        return {
            poolLibrary,
        }
    }
}
