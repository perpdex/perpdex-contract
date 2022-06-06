import { ethers, waffle } from "hardhat"
import { TestAccountLibrary } from "../../typechain"
import { Wallet } from "ethers"

interface AccountLibraryFixture {
    accountLibrary: TestAccountLibrary
    market1: Wallet
    market2: Wallet
}

export function createAccountLibraryFixture(): (wallets, provider) => Promise<AccountLibraryFixture> {
    return async ([owner, market1, market2], provider): Promise<AccountLibraryFixture> => {
        const factory = await ethers.getContractFactory("TestAccountLibrary")
        const accountLibrary = (await factory.deploy()) as TestAccountLibrary

        return {
            accountLibrary,
            market1,
            market2,
        }
    }
}
