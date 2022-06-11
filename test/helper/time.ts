export async function getTimestamp() {
    const blockNum = await hre.ethers.provider.getBlockNumber()
    const block = await hre.ethers.provider.getBlock(blockNum)
    return block.timestamp
}

export async function setNextTimestamp(value, mine = false) {
    await hre.ethers.provider.send("evm_setNextBlockTimestamp", [value])
    if (mine) {
        await hre.ethers.provider.send("evm_mine", [])
    }
}
