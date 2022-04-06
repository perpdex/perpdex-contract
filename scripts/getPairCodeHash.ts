const hre = require("hardhat")

async function main() {
    const UniswapV2Factory = await hre.ethers.getContractFactory("UniswapV2Factory")
    const factory = await UniswapV2Factory.deploy(hre.ethers.constants.AddressZero)
    await factory.deployed()

    console.log("pairCodeHash:", await factory.pairCodeHash())
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    })
