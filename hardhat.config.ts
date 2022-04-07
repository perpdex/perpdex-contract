import "@nomiclabs/hardhat-ethers"
import "@nomiclabs/hardhat-waffle"
import "@openzeppelin/hardhat-upgrades"
import "@typechain/hardhat"
import "hardhat-contract-sizer"
import "hardhat-dependency-compiler"
import "hardhat-gas-reporter"
import { HardhatUserConfig } from "hardhat/config"
import "solidity-coverage"
import "./mocha-test"

const config: HardhatUserConfig = {
    solidity: {
        version: "0.7.6",
        settings: {
            optimizer: { enabled: true, runs: 100 },
            evmVersion: "berlin",
            // for smock to mock contracts
            outputSelection: {
                "*": {
                    "*": ["storageLayout"],
                },
            },
        },
    },
    networks: {
        hardhat: {
            allowUnlimitedContractSize: true,
        },
    },
    dependencyCompiler: {
        // We have to compile from source since UniswapV3 doesn't provide artifacts in their npm package
        paths: [
            "@uniswap/v3-core/contracts/UniswapV3Factory.sol",
            "@uniswap/v3-core/contracts/UniswapV3Pool.sol",
            "deps/perpdex-oracle-contract/contracts/ChainlinkPriceFeed.sol",
            "deps/perpdex-oracle-contract/contracts/BandPriceFeed.sol",
            "deps/perpdex-oracle-contract/contracts/EmergencyPriceFeed.sol",
        ],
    },
    contractSizer: {
        alphaSort: true,
        runOnCompile: true,
        disambiguatePaths: false,
    },
    gasReporter: {
        excludeContracts: ["test"],
    },
    mocha: {
        require: ["ts-node/register/files"],
        jobs: 4,
        timeout: 120000,
        color: true,
    },
}

if (process.env.TESTNET_PRIVATE_KEY) {
    if (process.env.INFURA_PROJECT_ID) {
        config.networks.rinkeby = {
            url: "https://rinkeby.infura.io/v3/" + process.env.INFURA_PROJECT_ID,
            accounts: [process.env.TESTNET_PRIVATE_KEY],
        }
    }

    config.networks.mumbai = {
        url: "https://rpc-mumbai.maticvigil.com",
        accounts: [process.env.TESTNET_PRIVATE_KEY],
    }

    config.networks.fuji = {
        url: "https://api.avax-test.network/ext/bc/C/rpc",
        accounts: [process.env.TESTNET_PRIVATE_KEY],
    }
}

export default config
