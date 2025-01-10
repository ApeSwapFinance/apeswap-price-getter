import { ethers, network, upgrades } from 'hardhat'
import getNetworkConfig from '../../deploy-config'
import { DeployManager } from './DeployManager'
import { PriceGetterBackwardsCompatible__factory } from '../../typechain-types'

async function main() {
  const currentNetwork = network.name
  const {
    wNative,
    nativeLiquidityThreshold,
    stableUsdTokens,
    oracleTokens,
    oracles,
    proxyAdminContract,
    priceGetter
  } = getNetworkConfig(currentNetwork)

  const accounts = await ethers.getSigners()
  // Extract config for the network
  const [deployerAccount, hardhatAdminAccount, hardhatProxyAdminOwnerAddress] = accounts
  // Setup deploy manager
  const deployManager = await DeployManager.create({ signer: deployerAccount })

  console.log(wNative, nativeLiquidityThreshold, stableUsdTokens, oracleTokens, oracles)
  if (!stableUsdTokens.length || !oracleTokens.length || !oracles.length) {
    console.log('Stable USD tokens, oracle tokens, or oracles not provided')
    // throw new Error('Stable USD tokens, oracle tokens, and oracles must be provided')
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

  const priceGetterProtocols = [
    // { name: 'PriceGetterUniV2', protocol: 2 },
    // { name: 'PriceGetterUniV3', protocol: 3 },
    // { name: 'PriceGetterAlgebra', protocol: 4 },
    // { name: 'PriceGetterSolidly', protocol: 7 },
    { name: 'PriceGetterXfai', protocol: 8 },
    // { name: 'PriceGetterCurve', protocol: 9 },
  ]

  for (let i = 0; i < priceGetterProtocols.length; i++) {
    const priceGetterProtocol = priceGetterProtocols[i]
    const PriceGetterProtocolFactory = await ethers.getContractFactory(priceGetterProtocol.name)
    const PriceGetterProtocol = await deployManager.deployContractFromFactory(
      PriceGetterProtocolFactory,
      [],
      {
        name: priceGetterProtocol.name,
        estimateGas: false,
      }
    )
    console.log(`${priceGetterProtocol.name} deployed at ${PriceGetterProtocol.address}`)
    output.contracts[priceGetterProtocol.name] = PriceGetterProtocol.address


    if (priceGetter) {
      console.log('Deployed price getter found, updating price getter protocol. priceGetter:', priceGetter)
      const PriceGetterExtended = await PriceGetterBackwardsCompatible__factory.connect(priceGetter, deployerAccount)
      await PriceGetterExtended.setPriceGetterProtocol(priceGetterProtocol.protocol, PriceGetterProtocol.address)
    }
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
