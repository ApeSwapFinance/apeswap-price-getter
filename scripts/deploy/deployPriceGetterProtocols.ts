import { ethers, network, upgrades } from 'hardhat'
import getNetworkConfig from '../../deploy-config'
import { DeployManager } from './DeployManager'

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

  const output: { contracts: Record<string, string>, config: any } = {
    contracts: {},
    config: {
      wNative,
      stableUsdTokens,
      oracleTokens,
      oracles,
    },
  }

  const priceGetterProtocolNames = ['PriceGetterUniV2', 'PriceGetterUniV3', 'PriceGetterAlgebra', 'PriceGetterSolidly']
  for (let i = 0; i < priceGetterProtocolNames.length; i++) {
    const priceGetterProtocolName = priceGetterProtocolNames[i]
    const PriceGetterProtocolFactory = await ethers.getContractFactory(priceGetterProtocolName)
    const PriceGetterProtocol = await deployManager.deployContractFromFactory(
      PriceGetterProtocolFactory,
      [],
      {
        name: priceGetterProtocolName,
        estimateGas: false,
      }
    )
    console.log(`${priceGetterProtocolName} deployed at ${PriceGetterProtocol.address}`)
    output.contracts[priceGetterProtocolName] = PriceGetterProtocol.address
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
