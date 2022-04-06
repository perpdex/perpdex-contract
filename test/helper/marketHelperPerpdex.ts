import { MockContract } from "@eth-optimism/smock"
import { BigNumberish, BigNumber } from "ethers"
import { parseUnits } from "ethers/lib/utils"
import { ethers } from "hardhat"
import { UniswapV3Pool } from "../../typechain"
import { ClearingHousePerpdexFixture } from "../clearingHousePerpdex/fixtures"
import { encodePriceSqrt } from "../shared/utilities"
import { getMaxTick, getMinTick } from "./number"

export async function initMarket(
    fixture: ClearingHousePerpdexFixture,
    initPrice: BigNumberish,
    exFeeRatio: BigNumberish = 1000, // 0.1%
    ifFeeRatio: BigNumberish = 100000, // 10%
    maxPriceRocWithinBlockX96: BigNumberish = BigNumber.from("2").pow(96),
    baseToken: string = fixture.baseToken.address,
    mockedBaseAggregator: MockContract = fixture.mockedBaseAggregator,
): Promise<{ minTick: number; maxTick: number }> {
    mockedBaseAggregator.smocked.latestRoundData.will.return.with(async () => {
        return [0, parseUnits(initPrice.toString(), 6), 0, 0, 0]
    })

    // const poolAddr = await fixture.uniV3Factory.getPool(baseToken, fixture.quoteToken.address, fixture.uniFeeTier)

    // const uniPoolFactory = await ethers.getContractFactory("UniswapV3Pool")
    // const uniPool = uniPoolFactory.attach(poolAddr)
    // await uniPool.initialize(encodePriceSqrt(initPrice.toString(), "1"))
    // const uniFeeRatio = await uniPool.fee()
    // const tickSpacing = await uniPool.tickSpacing()

    // the initial number of oracle can be recorded is 1; thus, have to expand it
    // await uniPool.increaseObservationCardinalityNext(500)

    // update config
    const marketRegistry = fixture.marketRegistry
    // await marketRegistry.addPool(baseToken, uniFeeRatio)
    // await marketRegistry.setFeeRatio(baseToken, exFeeRatio)
    // await marketRegistry.setInsuranceFundFeeRatio(baseToken, ifFeeRatio)

    if (maxPriceRocWithinBlockX96 != 0) {
        await fixture.exchange.setMaxPriceRocWithinBlock(baseToken, maxPriceRocWithinBlockX96)
    }

    return { minTick: 0, maxTick: 1 << 31 }
    // return { minTick: getMinTick(tickSpacing), maxTick: getMaxTick(tickSpacing) }
}

// todo replace caller getMaxTickRange to default value
export async function initAndAddPool(
    fixture: ClearingHousePerpdexFixture,
    // pool: UniswapV3Pool,
    baseToken: string,
    sqrtPriceX96: BigNumberish,
    feeRatio: BigNumberish,
    maxPriceRocWithinBlockX96: BigNumberish = BigNumber.from("2").pow(96),
) {
    // await pool.initialize(sqrtPriceX96)
    // the initial number of oracle can be recorded is 1; thus, have to expand it
    // await pool.increaseObservationCardinalityNext(500)
    // add pool after it's initialized
    // await fixture.marketRegistry.addPool(baseToken, feeRatio)
    if (maxPriceRocWithinBlockX96 != 0) {
        await fixture.exchange.setMaxPriceRocWithinBlock(baseToken, maxPriceRocWithinBlockX96)
    }
}
