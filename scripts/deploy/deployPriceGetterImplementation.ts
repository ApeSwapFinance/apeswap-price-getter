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
    console.log('Stable USD tokens, oracle tokens, or oracles not provided')
    //   throw new Error('Stable USD tokens, oracle tokens, and oracles must be provided')
  }

  const PriceGetterExtendedFactory = await ethers.getContractFactory('PriceGetterBackwardsCompatible')
  const PriceGetterExtended = await deployManager.deployContractFromFactory(PriceGetterExtendedFactory, [], {
    name: 'PriceGetterExtended',
  })

  const output: { priceGetterExtendedImplementation: string, contracts: Record<string, string>, config: any } = {
    priceGetterExtendedImplementation: PriceGetterExtended.address,
    contracts: {},
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
