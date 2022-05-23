import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { parseEther } from "ethers/lib/utils"
import { ethers } from "hardhat"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts, getChainId } = hre
    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()

    const quoteTokenName = "QuoteEth"
    const quoteTokenSymbol = "QUOTEETH"

    await deploy("QuoteTokenNative", {
        from: deployer,
        contract: "QuoteTokenPerpdex",
        args: [quoteTokenName, quoteTokenSymbol],
        log: true,
        autoMine: true,
    })
}

export default func
func.tags = ["quote_tokens"]
