import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { parseEther } from "ethers/lib/utils"
import { ethers } from "hardhat"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre
    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()

    await deploy("UniswapV2Factory", {
        from: deployer,
        args: [ethers.constants.AddressZero],
        log: true,
        autoMine: true,
    })
}

export default func
func.tags = ["univ2_factory"]
