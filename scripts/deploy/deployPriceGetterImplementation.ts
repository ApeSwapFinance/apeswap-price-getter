import { ethers, network } from 'hardhat'
import getNetworkConfig from '../../deploy-config'
import { DeployManager } from './DeployManager'
import { PriceGetterExtended__factory } from '../../typechain-types'

async function main() {
  const currentNetwork = network.name
  const {
    wNative,
    factoryV2,
    nativeLiquidityThreshold,
    factoryV3,
    factoryAlgebra,
    factorySolidly,
    factoryXFAI,
    stableUsdTokens,
    oracleTokens,
    oracles,
    proxyAdminContract,
  } = getNetworkConfig(currentNetwork)

  const accounts = await ethers.getSigners()
  // Extract config for the network
  const [deployerAccount, hardhatAdminAccount, hardhatProxyAdminOwnerAddress] = accounts
  // Setup deploy manager
  const deployManager = await DeployManager.create({ signer: deployerAccount })

  console.log(wNative, nativeLiquidityThreshold, factoryV2, factoryV3, factoryAlgebra, factorySolidly, stableUsdTokens, oracleTokens, oracles)

  const priceGetterExtendedName = 'PriceGetterExtended'
  const PriceGetterExtendedFactory = await ethers.getContractFactory(priceGetterExtendedName)
  const PriceGetterExtended = await deployManager.deployContractFromFactory(
    PriceGetterExtendedFactory,
    [wNative, nativeLiquidityThreshold, factoryV2, factoryV3, factoryAlgebra, factorySolidly, factoryXFAI, stableUsdTokens, oracleTokens, oracles],
    {
      name: priceGetterExtendedName,
      estimateGas: false,
    }
  )

  const output = {
    priceGetterExtended: PriceGetterExtended.address,
    config: {
      wNative,
      factoryV2,
      factoryV3,
      factoryAlgebra,
      factorySolidly,
      stableUsdTokens,
      oracleTokens,
      oracles,
    },
  }

  console.dir(output, { depth: 5 })

  await delay(21000)
  // if failed to verify comment everything above this and edit line below to just verify
  // await deployManager.addDeployedContract('20230720-polygon-deployment.json')
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
