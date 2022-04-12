import hre from "hardhat"

export const config = {
    localhost: {
        // eth mainnet fork for test
        weth: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
        usdc: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        chainlinkDataFeed: {
            ethUsd: "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419",
        },
    },
    rinkeby: {
        weth: "0xc778417E063141139Fce010982780140Aa0cD5Ab",
        usdc: "0xeb8f08a975Ab53E34D8a0330E0D34de942C95926",
        chainlinkDataFeed: {
            ethUsd: "0x8A753747A1Fa494EC906cE90E9f37563A8AF630e",
        },
    },
    mumbai: {
        weth: "0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa",
        usdc: "0xe11A86849d99F524cAC3E7A0Ec1241828e332C62",
        chainlinkDataFeed: {
            ethUsd: "0x0715A7794a1dc8e42615F059dD6e406A6594651A",
        },
    },
    fuji: {
        weth: "0xd00ae08403B9bbb9124bB305C09058E32C39A48c", // WAVAX
        usdc: "0x5425890298aed601595a70AB815c96711a31Bc65",
        chainlinkDataFeed: {
            ethUsd: "0x5498BB86BC934c8D34FDA08E81D444153d0D06aD", // AVAX/USD
        },
    },
}[hre.network.name]

export async function safeVerify(address, args) {
    try {
        await hre.run("verify:verify", {
            address: address,
            constructorArguments: args,
        })
    } catch (err) {
        console.error(err)
    }
}
