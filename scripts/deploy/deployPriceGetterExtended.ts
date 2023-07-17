import { ethers } from 'hardhat'
import hre from 'hardhat'
import getNetworkConfig from '../../deploy-config'
import { DeployManager } from './DeployManager'

async function main() {
  const { wNative, factoryV2, factoryV3, factoryAlgebra, stableUsdTokens, oracleTokens, oracles } = getNetworkConfig(
    hre.network.name
  )
  const deployManager = new DeployManager()

  const contractName = 'PriceGetterExtended'
  const PriceGetterExtended = await ethers.getContractFactory(contractName)
  const priceGetterExtended = await deployManager.deployContractFromFactory(
    PriceGetterExtended,
    [wNative, factoryV2, factoryV3, factoryAlgebra, stableUsdTokens, oracleTokens, oracles],
    contractName // Pass in contract name to log contract
  )

  const output = {
    priceGetterExtended: priceGetterExtended.address,
    config: {
      wNative,
      factoryV2,
      factoryV3,
      stableUsdTokens,
      oracleTokens,
      oracles,
    },
  }

  console.dir(output, { depth: 5 })

  await delay(11000)
  // await deployManager.addDeployedContract('20230613-polygon-deployment.json')
  await deployManager.verifyContracts()
}

function delay(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
