import { ethers } from "hardhat"
import { config, safeVerify } from "./common"

async function main() {
    console.log("verify")

    const chainlinkPriceFeed = "0x6cC3F06C9e10EfbD9221C71Eab22c806FFCd4890"
    const quoteToken = "0x3B5656BbddaD7fedCB98E196bDcA1df3bab15DD0"
    const baseToken = "0xdf0dd408043d5a607911B5d960d787eB01366bE0"
    const uniV2Factory = "0xce20f16e655e39266D0F08CFf6565057E86d3892"
    const clearingHouseConfig = "0x06FEcEA4e91bcDBd7c8A60B5807c007abFB0cE4c"
    const marketRegistry = "0x495aD0f509850e6eCa8f38562443193187ccBa63"
    const orderBook = "0x01dD315eefDd5631259E10f4E0B869320D9DBFCa"
    const accountBalance = "0xb55c0F34398445246Dd1052f11D89439975b4538"
    const exchange = "0xA4017B92cF5611D39062B80f9Cd1086FCAd18a8D"
    const insuranceFund = "0xBE7503f47351A3407BfaA76C974CDd28e2F57EC4"
    const vault = "0x1174562E02E5102d156961634332b0A0C4EDaeC3"
    const clearingHouse = "0x53fcd82c21283Ac5ED5a469E2960f06d1e39b1EB"

    await safeVerify(chainlinkPriceFeed, [config.chainlinkDataFeed.ethUsd, 15 * 60])
    await safeVerify(quoteToken, [])
    await safeVerify(baseToken, [])
    await safeVerify(uniV2Factory, [ethers.constants.AddressZero])
    await safeVerify(clearingHouseConfig, [])
    await safeVerify(marketRegistry, [])
    await safeVerify(orderBook, [])
    await safeVerify(accountBalance, [])
    await safeVerify(exchange, [])
    await safeVerify(insuranceFund, [])
    await safeVerify(vault, [])
    await safeVerify(clearingHouse, [])

    console.log("verify finished")
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    })
