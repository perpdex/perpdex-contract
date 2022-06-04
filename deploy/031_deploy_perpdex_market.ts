import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { parseEther } from "ethers/lib/utils"
import { ethers } from "hardhat"
import { getPerpdexOracleContractDeployment as getOracleDeploy } from "../scripts/deployHelper"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts, getChainId } = hre
    const { deploy, execute } = deployments
    const { deployer } = await getNamedAccounts()

    const priceFeedQuoteAddress = {
        rinkeby: getOracleDeploy("ChainlinkPriceFeedETHUSD").address,
    }[hre.network.name]

    const markets = {
        rinkeby: [
            {
                symbol: "USD",
                priceFeedBase: hre.ethers.constants.AddressZero,
            },
            {
                symbol: "BTC",
                priceFeedBase: getOracleDeploy("ChainlinkPriceFeedBTCUSD").address,
            },
            {
                symbol: "LINK",
                priceFeedBase: getOracleDeploy("ChainlinkPriceFeedLINKUSD").address,
            },
            {
                symbol: "MATIC",
                priceFeedBase: getOracleDeploy("ChainlinkPriceFeedMATICUSD").address,
            },
        ],
    }[hre.network.name]

    const perpdexExchange = await deployments.get("PerpdexExchange")

    for (let i = 0; i < markets.length; i++) {
        const market = await deploy("PerpdexMarket" + markets[i].symbol, {
            from: deployer,
            contract: "PerpdexMarket",
            args: [markets[i].symbol, perpdexExchange.address, markets[i].priceFeedBase, priceFeedQuoteAddress],
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
