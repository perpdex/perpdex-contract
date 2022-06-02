import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { parseEther } from "ethers/lib/utils"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts, getChainId } = hre
    const { deploy, execute } = deployments
    const { deployer } = await getNamedAccounts()

    const perpdexExchange = await deployments.get("PerpdexExchange")

    await deploy("PerpdexRouter", {
        from: deployer,
        args: [perpdexExchange.address],
        log: true,
        autoMine: true,
    })
}

export default func
func.tags = ["PerpdexRouter"]
