import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { parseEther } from "ethers/lib/utils"
import { ethers } from "hardhat"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts, getChainId } = hre
    const { deploy, execute } = deployments
    const { deployer } = await getNamedAccounts()

    const markets = [
        {
            symbol: "USD",
            priceFeedAddress: {
                "4": "0x8F9aC0A22e5aC2A6dda0C1d4Ce17B5c079D094F0", // WETH rinkeby
            }[await getChainId()],
        },
    ]

    const perpdexExchange = await deployments.get("PerpdexExchange")

    for (let i = 0; i < markets.length; i++) {
        const market = await deploy("PerpdexMarket" + markets[i].symbol, {
            from: deployer,
            contract: "PerpdexMarket",
            args: [markets[i].symbol, perpdexExchange.address, markets[i].priceFeedAddress],
            log: true,
            autoMine: true,
        })

        await execute(
            "PerpdexExchange",
            {
                from: deployer,
                log: true,
                autoMine: true,
            },
            "setIsMarketAllowed",
            market.address,
            true,
        )
    }
}

export default func
func.tags = ["Markets"]
