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
    const accountLibrary = await deployments.get("AccountLibrary")
    const takerLibrary = await deployments.get("TakerLibrary")
    const makerLibrary = await deployments.get("MakerLibrary")

    await deploy("ClearingHousePerpdexNew", {
        from: deployer,
        args: [quoteTokenName, quoteTokenSymbol, uniV2Factory.address],
        libraries: {
            AccountLibrary: accountLibrary.address,
            TakerLibrary: takerLibrary.address,
            MakerLibrary: makerLibrary.address,
        },
        log: true,
        autoMine: true,
    })
}

export default func
func.tags = ["ClearingHousePerpdexNew"]
