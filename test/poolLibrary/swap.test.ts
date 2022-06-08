import { expect } from "chai"
import { waffle } from "hardhat"
import { TestPoolLibrary } from "../../typechain"
import { createPoolLibraryFixture } from "./fixtures"
import { BigNumber, BigNumberish, Wallet } from "ethers"
import { MockContract } from "ethereum-waffle"

describe("PoolLibrary swap", () => {
    let loadFixture = waffle.createFixtureLoader(waffle.provider.getWallets())
    let fixture

    let library: TestPoolLibrary

    const Q96 = BigNumber.from(2).pow(96)

    beforeEach(async () => {
        fixture = await loadFixture(createPoolLibraryFixture())
        library = fixture.poolLibrary
    })

    describe("empty pool", () => {
        it("revert", async () => {
            await expect(
                library.swap({
                    isBaseToQuote: false,
                    isExactInput: true,
                    amount: 1,
                    feeRatio: 0,
                }),
            ).to.be.reverted
        })
    })

    describe("without fee, without funding", () => {
        beforeEach(async () => {
            await library.setPoolInfo({
                base: 10000,
                quote: 10000,
                totalLiquidity: 10000,
                cumDeleveragedBasePerLiquidityX96: 0,
                cumDeleveragedQuotePerLiquidityX96: 0,
                baseBalancePerShareX96: Q96,
            })
        })
        ;[
            {
                title: "long exact input",
                isBaseToQuote: false,
                isExactInput: true,
                amount: 10000,
                oppositeAmount: 5000,
                base: 5000,
                quote: 20000,
            },
            {
                title: "short exact input",
                isBaseToQuote: true,
                isExactInput: true,
                amount: 10000,
                oppositeAmount: 5000,
                base: 20000,
                quote: 5000,
            },
            {
                title: "long exact output",
                isBaseToQuote: false,
                isExactInput: false,
                amount: 5000,
                oppositeAmount: 10000,
                base: 5000,
                quote: 20000,
            },
            {
                title: "short exact input",
                isBaseToQuote: true,
                isExactInput: false,
                amount: 5000,
                oppositeAmount: 10000,
                base: 20000,
                quote: 5000,
            },
            {
                title: "long exact input zero",
                isBaseToQuote: false,
                isExactInput: true,
                amount: 0,
                revertedWith: "PL_SD: output is zero",
            },
            {
                title: "short exact input zero",
                isBaseToQuote: true,
                isExactInput: true,
                amount: 0,
                revertedWith: "PL_SD: output is zero",
            },
            {
                title: "long exact output zero",
                isBaseToQuote: false,
                isExactInput: false,
                amount: 0,
                revertedWith: "PL_SD: output is zero",
            },
            {
                title: "short exact input zero",
                isBaseToQuote: true,
                isExactInput: false,
                amount: 0,
                revertedWith: "PL_SD: output is zero",
            },
            {
                title: "long exact input rounded to benefit pool",
                isBaseToQuote: false,
                isExactInput: true,
                amount: 10001,
                oppositeAmount: 5000,
                base: 5000,
                quote: 20001,
            },
            {
                title: "short exact input rounded to benefit pool",
                isBaseToQuote: true,
                isExactInput: true,
                amount: 10001,
                oppositeAmount: 5000,
                base: 20001,
                quote: 5000,
            },
            {
                title: "long exact output rounded to benefit pool",
                isBaseToQuote: false,
                isExactInput: false,
                amount: 5001,
                oppositeAmount: 10005,
                base: 4999,
                quote: 20005,
            },
            {
                title: "short exact output rounded to benefit pool",
                isBaseToQuote: true,
                isExactInput: false,
                amount: 5001,
                oppositeAmount: 10005,
                base: 20005,
                quote: 4999,
            },
            {
                title: "long revert when output is too small",
                isBaseToQuote: false,
                isExactInput: true,
                amount: 1,
                revertedWith: "PL_SD: output is zero",
            },
            {
                title: "short revert when output is too small",
                isBaseToQuote: true,
                isExactInput: true,
                amount: 1,
                revertedWith: "PL_SD: output is zero",
            },
            {
                title: "long revert when insufficient base liquidity",
                isBaseToQuote: false,
                isExactInput: false,
                amount: 10000,
                revertedWith: "",
            },
            {
                title: "short revert when insufficient quote liquidity",
                isBaseToQuote: true,
                isExactInput: false,
                amount: 10000,
                revertedWith: "",
            },
            {
                title: "long revert when insufficient base liquidity over",
                isBaseToQuote: false,
                isExactInput: false,
                amount: 10001,
                revertedWith: "SafeMath: subtraction overflow",
            },
            {
                title: "short revert when insufficient quote liquidity over",
                isBaseToQuote: true,
                isExactInput: false,
                amount: 10001,
                revertedWith: "SafeMath: subtraction overflow",
            },
            {
                title: "long revert when too large amount",
                isBaseToQuote: false,
                isExactInput: true,
                amount: BigNumber.from(2).pow(256).sub(1),
                revertedWith: "SafeMath: addition overflow",
            },
            {
                title: "short revert when too large amount",
                isBaseToQuote: true,
                isExactInput: true,
                amount: BigNumber.from(2).pow(256).sub(1),
                revertedWith: "SafeMath: addition overflow",
            },
            {
                title: "liquidity remain when too large long not overflow",
                isBaseToQuote: false,
                isExactInput: true,
                amount: BigNumber.from(2).pow(128),
                oppositeAmount: 9999,
                base: 1,
                quote: BigNumber.from(2).pow(128).add(10000),
            },
            {
                title: "liquidity remain when too large short not overflow",
                isBaseToQuote: true,
                isExactInput: true,
                amount: BigNumber.from(2).pow(128),
                oppositeAmount: 9999,
                base: BigNumber.from(2).pow(128).add(10000),
                quote: 1,
            },
        ].forEach(test => {
            it(test.title, async () => {
                const res = expect(
                    library.swap({
                        isBaseToQuote: test.isBaseToQuote,
                        isExactInput: test.isExactInput,
                        amount: test.amount,
                        feeRatio: 0,
                    }),
                )
                if (test.revertedWith !== void 0) {
                    await res.to.revertedWith(test.revertedWith)
                } else {
                    await res.to.emit(library, "SwapResult").withArgs(test.oppositeAmount)
                    const poolInfo = await library.poolInfo()
                    expect(poolInfo.base).to.eq(test.base)
                    expect(poolInfo.quote).to.eq(test.quote)
                    expect(poolInfo.totalLiquidity).to.eq(10000)
                    expect(poolInfo.cumDeleveragedBasePerLiquidityX96).to.eq(0)
                    expect(poolInfo.cumDeleveragedQuotePerLiquidityX96).to.eq(0)
                    expect(poolInfo.baseBalancePerShareX96).to.eq(Q96)
                }
            })

            it(test.title + " dry", async () => {
                if (test.revertedWith !== void 0) {
                    await expect(
                        library.swapDry(10000, 10000, {
                            isBaseToQuote: test.isBaseToQuote,
                            isExactInput: test.isExactInput,
                            amount: test.amount,
                            feeRatio: 0,
                        }),
                    ).to.revertedWith(test.revertedWith)
                } else {
                    const res = await library.swapDry(10000, 10000, {
                        isBaseToQuote: test.isBaseToQuote,
                        isExactInput: test.isExactInput,
                        amount: test.amount,
                        feeRatio: 0,
                    })
                    expect(res).to.eq(test.oppositeAmount)
                }
            })
        })
    })

    describe("with fee, without funding", () => {
        const feeRatio = 1e4

        beforeEach(async () => {
            await library.setPoolInfo({
                base: 10000,
                quote: 10000,
                totalLiquidity: 10000,
                cumDeleveragedBasePerLiquidityX96: 0,
                cumDeleveragedQuotePerLiquidityX96: 0,
                baseBalancePerShareX96: Q96,
            })
        })
        ;[
            {
                title: "long exact input",
                isBaseToQuote: false,
                isExactInput: true,
                amount: 10100,
                oppositeAmount: 5000,
                base: 5000,
                quote: 20100,
            },
            {
                title: "short exact input",
                isBaseToQuote: true,
                isExactInput: true,
                amount: 10100,
                oppositeAmount: 5000,
                base: 20100,
                quote: 5000,
            },
            {
                title: "long exact output",
                isBaseToQuote: false,
                isExactInput: false,
                amount: 5000,
                oppositeAmount: 10100,
                base: 5000,
                quote: 20100,
            },
            {
                title: "short exact input",
                isBaseToQuote: true,
                isExactInput: false,
                amount: 5000,
                oppositeAmount: 10100,
                base: 20100,
                quote: 5000,
            },
        ].forEach(test => {
            it(test.title, async () => {
                await expect(
                    library.swap({
                        isBaseToQuote: test.isBaseToQuote,
                        isExactInput: test.isExactInput,
                        amount: test.amount,
                        feeRatio: feeRatio,
                    }),
                )
                    .to.emit(library, "SwapResult")
                    .withArgs(test.oppositeAmount)
                const poolInfo = await library.poolInfo()
                expect(poolInfo.base).to.eq(test.base)
                expect(poolInfo.quote).to.eq(test.quote)
                expect(poolInfo.totalLiquidity).to.eq(10000)
                expect(poolInfo.cumDeleveragedBasePerLiquidityX96).to.eq(0)
                expect(poolInfo.cumDeleveragedQuotePerLiquidityX96).to.eq(0)
                expect(poolInfo.baseBalancePerShareX96).to.eq(Q96)
            })

            it(test.title + " dry", async () => {
                const res = await library.swapDry(10000, 10000, {
                    isBaseToQuote: test.isBaseToQuote,
                    isExactInput: test.isExactInput,
                    amount: test.amount,
                    feeRatio: feeRatio,
                })
                expect(res).to.eq(test.oppositeAmount)
            })
        })
    })
})
