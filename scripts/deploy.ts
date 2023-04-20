import { ethers } from 'hardhat'
import hre from 'hardhat'
import getNetworkConfig from '../deploy-config'

async function main() {
  const { wNative, factoryV2, factoryV3, stableUsdTokens, oracleTokens, oracles } = getNetworkConfig(hre.network.name)

  const PriceGetter = await ethers.getContractFactory('PriceGetter')
  const priceGetter = await PriceGetter.deploy(wNative, factoryV2, factoryV3, stableUsdTokens, oracleTokens, oracles)

  await priceGetter.deployed()

  console.log('PriceGetter deployed to:', priceGetter.address)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
