import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { parseEther } from "ethers/lib/utils"
import { ethers } from "hardhat"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts, getChainId } = hre
    const { deploy, execute } = deployments
    const { deployer } = await getNamedAccounts()

    const baseTokens = [
        {
            name: "BaseTokenUsd",
            symbol: "BASEUSD",
        },
    ]

    const clearingHouse = await deployments.get("ClearingHousePerpdexNew")

    for (let i = 0; i < baseTokens.length; i++) {
        const baseToken = await deploy(baseTokens[i].name, {
            from: deployer,
            contract: "BaseTokenPerpdex",
            args: [baseTokens[i].name, baseTokens[i].symbol, clearingHouse.address],
            log: true,
            autoMine: true,
        })

        await execute(
            "ClearingHousePerpdexNew",
            {
                from: deployer,
                log: true,
                autoMine: true,
            },
            "setIsBaseTokenAllowed",
            baseToken.address,
            true,
        )
    }
}

export default func
func.tags = ["quote_tokens"]
