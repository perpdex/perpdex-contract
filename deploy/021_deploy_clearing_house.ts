import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { parseEther } from "ethers/lib/utils"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre
    const { deploy, execute } = deployments
    const { deployer } = await getNamedAccounts()

    const quoteTokenName = "QuoteEth"
    const quoteTokenSymbol = "QUOTEETH"

    const uniV2Factory = await deployments.get("UniswapV2Factory")

    await deploy("ClearingHousePerpdexNew", {
        from: deployer,
        args: [quoteTokenName, quoteTokenSymbol, uniV2Factory.address],
        log: true,
        autoMine: true,
    })
}

export default func
func.tags = ["ClearingHousePerpdexNew"]
