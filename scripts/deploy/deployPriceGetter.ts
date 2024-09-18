import { ethers, network, upgrades } from 'hardhat'
import getNetworkConfig from '../../deploy-config'
import { DeployManager } from './DeployManager'
import { PriceGetter__factory } from '../../typechain-types'

async function main() {
  const currentNetwork = network.name
  const {
    wNative,
    nativeLiquidityThreshold,
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

  console.log(wNative, nativeLiquidityThreshold, stableUsdTokens, oracleTokens, oracles)
  if (!stableUsdTokens.length || !oracleTokens.length || !oracles.length) {
    throw new Error('Stable USD tokens, oracle tokens, and oracles must be provided')
  }

  const { implementationThroughProxy: PriceGetterExtended, implementation: PriceGetterExtended_Implementation } =
    await deployManager.deployUpgradeableContract<PriceGetter__factory>(
      'PriceGetter',
      [wNative, nativeLiquidityThreshold, stableUsdTokens, oracleTokens, oracles],
      {
        proxyAdminAddress: proxyAdminContract,
      }
    )

  const output = {
    priceGetterExtended: PriceGetterExtended.address,
    priceGetterExtendedImplementation: PriceGetterExtended_Implementation.address,
    config: {
      wNative,
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
