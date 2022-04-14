import { expect } from "chai"
import { parseEther, parseUnits } from "ethers/lib/utils"
import { ethers, waffle } from "hardhat"
import { BaseToken } from "../../typechain"
import { baseTokenEmptyFixture } from "./fixtures"

describe("BaseTokenEmpty", async () => {
    const [admin, user] = waffle.provider.getWallets()
    const loadFixture: ReturnType<typeof waffle.createFixtureLoader> = waffle.createFixtureLoader([admin])
    let baseToken: BaseToken

    beforeEach(async () => {
        const _fixture = await loadFixture(baseTokenEmptyFixture)
        baseToken = _fixture.baseToken
    })

    describe("twap", () => {
        it("twap price", async () => {
            const price = await baseToken.getIndexPrice(45)
            expect(price).to.eq(parseEther("0"))
        })
    })
})
