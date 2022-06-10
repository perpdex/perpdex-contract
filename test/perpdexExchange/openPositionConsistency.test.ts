import { expect } from "chai"
import { waffle } from "hardhat"
import { TestPerpdexExchange, TestPerpdexMarket } from "../../typechain"
import { createPerpdexExchangeFixture } from "./fixtures"
import { BigNumber, BigNumberish, Wallet } from "ethers"

describe("PerpdexExchange openPosition consistency", () => {
    let loadFixture = waffle.createFixtureLoader(waffle.provider.getWallets())
    let fixture

    let exchange: TestPerpdexExchange
    let market: TestPerpdexMarket
    let owner: Wallet
    let alice: Wallet
    let bob: Wallet

    const Q96 = BigNumber.from(2).pow(96)
    const deadline = Q96
    const initialPoolAmount = BigNumber.from(10).pow(18)
    const maxUint = BigNumber.from(2).pow(256).sub(1)

    beforeEach(async () => {
        fixture = await loadFixture(createPerpdexExchangeFixture())
        exchange = fixture.perpdexExchange
        market = fixture.perpdexMarket
        owner = fixture.owner
        alice = fixture.alice
        bob = fixture.bob

        await exchange.connect(owner).setImRatio(10e4)
        await exchange.connect(owner).setMmRatio(5e4)
        await exchange.connect(owner).setLiquidationRewardConfig({
            rewardRatio: 25e4,
            smoothEmaTime: 1,
        })

        await market.connect(owner).setPoolFeeRatio(0)
        await market.connect(owner).setFundingMaxPremiumRatio(0)
        await exchange.connect(owner).setIsMarketAllowed(market.address, true)
        await market.connect(owner).setPriceLimitConfig({
            normalOrderRatio: 5e4,
            liquidationRatio: 10e4,
            emaNormalOrderRatio: 5e4,
            emaLiquidationRatio: 10e4,
            emaSec: 300,
        })

        await exchange.setAccountInfo(
            owner.address,
            {
                collateralBalance: initialPoolAmount,
            },
            [],
        )

        await exchange.connect(owner).addLiquidity({
            market: market.address,
            base: initialPoolAmount,
            quote: initialPoolAmount,
            minBase: 0,
            minQuote: 0,
            deadline: deadline,
        })
    })
    ;[0, 5e4].forEach(fee => {
        ;[0, 1e4].forEach(protocolFee => {
            ;[false, true].forEach(isBaseToQuote => {
                ;[false, true].forEach(isExactInput => {
                    ;[false, true].forEach(isLiquidation => {
                        describe(`fee ${fee} protocolFee ${protocolFee} isBaseToQuote ${isBaseToQuote} isExactInput ${isExactInput} isLiquidation ${isLiquidation}`, () => {
                            let amount

                            beforeEach(async () => {
                                await market.connect(owner).setPoolFeeRatio(fee)
                                await exchange.connect(owner).setProtocolFeeRatio(protocolFee)

                                await exchange.setAccountInfo(
                                    alice.address,
                                    {
                                        collateralBalance: initialPoolAmount,
                                    },
                                    [market.address],
                                )

                                amount = await exchange.maxOpenPosition({
                                    trader: alice.address,
                                    market: market.address,
                                    caller: alice.address,
                                    isBaseToQuote: isBaseToQuote,
                                    isExactInput: isExactInput,
                                })
                            })

                            it("openPosition revert condition with maxOpenPosition", async () => {
                                const res2 = exchange.connect(alice).openPosition({
                                    trader: alice.address,
                                    market: market.address,
                                    isBaseToQuote: isBaseToQuote,
                                    isExactInput: isExactInput,
                                    amount: amount.add(1000),
                                    oppositeAmountBound: isExactInput ? 0 : maxUint,
                                    deadline: deadline,
                                })
                                await expect(res2).to.reverted

                                const res = exchange.connect(alice).openPosition({
                                    trader: alice.address,
                                    market: market.address,
                                    isBaseToQuote: isBaseToQuote,
                                    isExactInput: isExactInput,
                                    amount: amount,
                                    oppositeAmountBound: isExactInput ? 0 : maxUint,
                                    deadline: deadline,
                                })
                                await expect(res).not.to.reverted
                            })

                            it("previewOpenPosition revert condition with maxOpenPosition", async () => {
                                const res2 = exchange.previewOpenPosition({
                                    trader: alice.address,
                                    market: market.address,
                                    caller: alice.address,
                                    isBaseToQuote: isBaseToQuote,
                                    isExactInput: isExactInput,
                                    amount: amount.add(1000),
                                    oppositeAmountBound: isExactInput ? 0 : maxUint,
                                })
                                await expect(res2).to.reverted

                                const res = exchange.previewOpenPosition({
                                    trader: alice.address,
                                    market: market.address,
                                    caller: alice.address,
                                    isBaseToQuote: isBaseToQuote,
                                    isExactInput: isExactInput,
                                    amount: amount,
                                    oppositeAmountBound: isExactInput ? 0 : maxUint,
                                })
                                await expect(res).not.to.reverted
                            })

                            it("openPosition and previewOpenPosition", async () => {
                                const previewBaseQuote = exchange.previewOpenPosition({
                                    trader: alice.address,
                                    market: market.address,
                                    caller: alice.address,
                                    isBaseToQuote: isBaseToQuote,
                                    isExactInput: isExactInput,
                                    amount: amount,
                                    oppositeAmountBound: isExactInput ? 0 : maxUint,
                                })

                                const res = exchange.connect(alice).openPosition({
                                    trader: alice.address,
                                    market: market.address,
                                    isBaseToQuote: isBaseToQuote,
                                    isExactInput: isExactInput,
                                    amount: amount,
                                    oppositeAmountBound: isExactInput ? 0 : maxUint,
                                    deadline: deadline,
                                })
                                await expect(res).to.emit(exchange, "PositionChanged")

                                // TODO: compare results with previewBaseQuote
                            })
                        })
                    })
                })
            })
        })
    })
})
