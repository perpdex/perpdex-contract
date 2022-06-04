import fs from "fs"
import path from "path"
import hre from "hardhat"

interface Deployment {
    address: string
    abi: object[]
}

export function getPerpdexOracleContractDeployment(name: string): Deployment {
    const networkName = hre.network.name
    const fname = path.resolve(__dirname, `../deps/perpdex-oracle-contract/deployments/${networkName}/${name}.json`)
    return JSON.parse(fs.readFileSync(fname, "utf8"))
}
