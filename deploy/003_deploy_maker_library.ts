import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { parseEther } from "ethers/lib/utils"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre
    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()

    await deploy("MakerLibrary", {
        from: deployer,
        libraries: {
            AccountLibrary: (await deployments.get("AccountLibrary")).address,
            TakerLibrary: (await deployments.get("TakerLibrary")).address,
        },
        log: true,
        autoMine: true,
    })
}

export default func
func.tags = ["libraries"]
