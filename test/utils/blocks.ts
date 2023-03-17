import { ethers, network } from 'hardhat'

export async function gasUsed(): Promise<string> {
    const blockNumber = await ethers.provider.getBlockNumber()
    const block = await ethers.provider.getBlock(blockNumber)
    return block.gasUsed.toString()
}

export async function mineNBlocks(n: number) {
    console.log('skipping blocks: ', n)
    for (let index = 0; index < n; index++) {
      await network.provider.send('evm_mine', []);
    }
}
