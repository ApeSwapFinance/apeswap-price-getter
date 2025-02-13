import { HardhatUserConfig } from 'hardhat/config'
// import '@nomicfoundation/hardhat-toolbox'
import 'solidity-coverage'
import 'hardhat-docgen'
import 'hardhat-contract-sizer'
import '@typechain/hardhat'

import { task, types } from 'hardhat/config'
import { TASK_TEST } from 'hardhat/builtin-tasks/task-names'
import {
  HardhatRuntimeEnvironment,
  HttpNetworkAccountsUserConfig,
  HttpNetworkUserConfig,
  NetworkUserConfig,
  SolcUserConfig,
} from 'hardhat/types'

import { Task, Verifier, Network } from './hardhat'
import { getEnv, Logger, logger, testRunner } from './hardhat/utils'
import solhintConfig from './solhint.config'
import '@openzeppelin/hardhat-upgrades'
import '@nomicfoundation/hardhat-verify'

/**
 * Deploy contracts based on a directory ID in tasks/
 *
 * `npx hardhat deploy --id <task-id> --network <network-name> [--key <apiKey> --force --verbose]`
 */
task('deploy', '🫶 Run deployment task')
  .addParam('id', 'Deployment task ID')
  .addFlag('force', 'Ignore previous deployments')
  .addOptionalParam('key', 'Etherscan API key to verify contracts')
  .setAction(
    async (args: { id: string; force?: boolean; key?: string; verbose?: boolean }, hre: HardhatRuntimeEnvironment) => {
      // Logger.setDefaults(false, args.verbose || false)
      const key = parseApiKey(hre.network.name as Network, args.key)
      const verifier = key ? new Verifier(hre.network, key) : undefined
      await Task.fromHRE(args.id, hre, verifier).run(args)
    }
  )

/**
 * Verify contracts based on a directory ID in tasks/
 *
 * eg: `npx hardhat verify-contract --id <task-id> --network <network-name> --name <contract-name>
 *  [--address <contract-address> --args <constructor-args --key <apiKey> --force --verbose]`
 */
task('verify-contract', '🫶 Run verification for a given contract')
  .addParam('id', 'Deployment task ID')
  .addParam('name', 'Contract name')
  .addOptionalParam('address', 'Contract address')
  .addOptionalParam('args', 'ABI-encoded constructor arguments')
  .addOptionalParam('key', 'Etherscan API key to verify contracts')
  .setAction(
    async (
      args: {
        id: string
        name: string
        address?: string
        key?: string
        args?: string
        verbose?: boolean
      },
      hre: HardhatRuntimeEnvironment
    ) => {
      // Logger.setDefaults(false, args.verbose || false)
      const key = parseApiKey(hre.network.name as Network, args.key)
      const verifier = key ? new Verifier(hre.network, key) : undefined

      await Task.fromHRE(args.id, hre, verifier).verify(args.name, args.address, args.args)
    }
  )

task('print-tasks', '🫶 Prints available tasks in tasks/ directory').setAction(async (args: { verbose?: boolean }) => {
  // Logger.setDefaults(false, args.verbose || false)
  logger.log(
    `Use the following tasks in a variety of ways \nnpx hardhat deploy --id <task-id> --network <network-name> \nnpx hardhat verify-contract --id <task-id> --network <network-name> --name <contract-name> \n`,
    `🫶`
  )
  Task.printAllTask()
})

/**
 * Example of accessing ethers and performing Web3 calls inside a task
 * task action function receives the Hardhat Runtime Environment as second argument
 *
 * Docs regarding hardhat helper functions added to ethers object:
 * https://github.com/NomicFoundation/hardhat/tree/master/packages/hardhat-ethers#helpers
 */
task('blockNumber', '🫶 Prints the current block number', async (_, hre: HardhatRuntimeEnvironment) => {
  // A provider field is added to ethers, which is an
  //   ethers.providers.Provider automatically connected to the selected network
  await hre.ethers.provider.getBlockNumber().then((blockNumber) => {
    console.log('Current block number: ' + blockNumber)
  })
})

/**
 * Provide additional fork testing options
 *
 * eg: `npx hardhat test --fork <network-name> --blockNumber <block-number>`
 */
task(TASK_TEST, '🫶 Test Task')
  .addOptionalParam('fork', 'Optional network name to be forked block number to fork in case of running fork tests.')
  .addOptionalParam('blockNumber', 'Optional block number to fork in case of running fork tests.', undefined, types.int)
  .setAction(testRunner)

const mainnetMnemonic = getEnv('MAINNET_MNEMONIC')
const mainnetPrivateKey = getEnv('MAINNET_PRIVATE_KEY')
const mainnetAccounts: HttpNetworkAccountsUserConfig | undefined = mainnetMnemonic
  ? { mnemonic: mainnetMnemonic }
  : mainnetPrivateKey
    ? [mainnetPrivateKey] // Fallback to private key
    : undefined

const testnetMnemonic = getEnv('TESTNET_MNEMONIC')
const testnetPrivateKey = getEnv('TESTNET_PRIVATE_KEY')
const testnetAccounts: HttpNetworkAccountsUserConfig | undefined = testnetMnemonic
  ? { mnemonic: testnetMnemonic }
  : testnetPrivateKey
    ? [testnetPrivateKey] // Fallback to private key
    : undefined

type ExtendedNetworkOptions = {
  getExplorerUrl: (address: string) => string
}

type NetworkUserConfigExtended = HttpNetworkUserConfig & ExtendedNetworkOptions

// Custom type for the hardhat network
type ExtendedHardhatNetworkConfig = {
  [K in Network]: K extends 'hardhat' ? HardhatUserConfig & ExtendedNetworkOptions : NetworkUserConfigExtended
}

const networkConfig: ExtendedHardhatNetworkConfig = {
  mainnet: {
    url: getEnv('MAINNET_RPC_URL') || 'https://rpc.ankr.com/eth',
    getExplorerUrl: (address: string) => `https://etherscan.io/address/${address}`,
    chainId: 1,
    accounts: mainnetAccounts,
  },
  goerli: {
    url: getEnv('GOERLI_RPC_URL') || '',
    getExplorerUrl: (address: string) => `https://goerli.etherscan.io/address/${address}`,
    chainId: 5,
    accounts: testnetAccounts,
  },
  arbitrum: {
    url: getEnv('ARBITRUM_RPC_URL') || 'https://arbitrum-one.publicnode.com',
    getExplorerUrl: (address: string) => `https://arbiscan.io/address/${address}`,
    chainId: 42161,
    accounts: mainnetAccounts,
  },
  arbitrumGoerli: {
    url: getEnv('ARBITRUM_GOERLI_RPC_URL') || '',
    getExplorerUrl: (address: string) => `https://testnet.arbiscan.io/address/${address}`,
    chainId: 421613,
    accounts: testnetAccounts,
  },
  bsc: {
    url: getEnv('BSC_RPC_URL') || 'https://binance.llamarpc.com',
    getExplorerUrl: (address: string) => `https://bscscan.com/address/${address}`,
    chainId: 56,
    accounts: mainnetAccounts,
  },
  bscTestnet: {
    url: getEnv('BSC_TESTNET_RPC_URL') || 'https://data-seed-prebsc-1-s1.binance.org:8545',
    getExplorerUrl: (address: string) => `https://testnet.bscscan.com/address/${address}`,
    chainId: 97,
    accounts: testnetAccounts,
  },
  linea: {
    url: getEnv('LINEA_RPC_URL') || 'https://rpc.linea.build',
    getExplorerUrl: (address: string) => `https://lineascan.build/address/${address}`,
    chainId: 59144,
    accounts: mainnetAccounts,
  },
  lineaTestnet: {
    url: getEnv('LINEA_TESTNET_RPC_URL') || 'https://rpc.goerli.linea.build',
    getExplorerUrl: (address: string) => `https://goerli.lineascan.build/address/${address}`,
    chainId: 59140,
    accounts: testnetAccounts,
  },
  polygon: {
    url: getEnv('POLYGON_RPC_URL') || 'https://polygon.llamarpc.com	',
    getExplorerUrl: (address: string) => `https://polygonscan.com/address/${address}`,
    chainId: 137,
    accounts: mainnetAccounts,
  },
  polygonTestnet: {
    url: getEnv('POLYGON_TESTNET_RPC_URL') || 'https://rpc-mumbai.maticvigil.com/',
    getExplorerUrl: (address: string) => `https://mumbai.polygonscan.com/address/${address}`,
    chainId: 80001,
    accounts: testnetAccounts,
  },
  lightlink: {
    url: 'https://replicator.phoenix.lightlink.io/rpc/v1',
    getExplorerUrl: (address: string) => `https://phoenix.lightlink.io/address/${address}`,
    chainId: 1890,
    accounts: mainnetAccounts,
  },
  iota: {
    url: 'https://json-rpc.evm.iotaledger.net',
    getExplorerUrl: (address: string) => `https://explorer.evm.iota.org/address/${address}`,
    chainId: 8822,
    accounts: mainnetAccounts,
  },
  base: {
    url: 'https://base.llamarpc.com',
    getExplorerUrl: (address: string) => `https://basescan.org/address/${address}`,
    chainId: 8453,
    accounts: mainnetAccounts,
  },
  blast: {
    url: 'https://rpc.blast.io',
    getExplorerUrl: (address: string) => `https://blastscan.io/address/${address}`,
    chainId: 81457,
    accounts: mainnetAccounts,
  },
  telos: {
    url: getEnv('TELOS_RPC_URL') || 'https://mainnet.telos.net/evm',
    getExplorerUrl: (address: string) => `https://www.teloscan.io/address/${address}`,
    chainId: 40,
    accounts: testnetAccounts,
  },
  telosTestnet: {
    url: getEnv('TELOS_TESTNET_RPC_URL') || 'https://testnet.telos.net/evm',
    getExplorerUrl: (address: string) => `https://testnet.teloscan.io/address/${address}`,
    chainId: 41,
    accounts: testnetAccounts,
  },
  avalanche: {
    url: 'https://endpoints.omniatech.io/v1/avax/mainnet/public',
    getExplorerUrl: (address: string) => `https://snowtrace.io/address/${address}`,
    chainId: 43114,
    accounts: mainnetAccounts,
  },
  singularityTestnet: {
    url: getEnv('SINGULARITY_TESTNET_RPC_URL') || 'https://rpc-testnet.singularityfinance.ai',
    getExplorerUrl: (address: string) => `https://explorer-testnet.singularityfinance.ai/address/${address}`,
    chainId: 751,
    accounts: testnetAccounts,
  },
  crossfi: {
    url: getEnv('CROSSFI_RPC_URL') || 'https://rpc.mainnet.ms/',
    getExplorerUrl: (address: string) => `https://xfiscan.com/address/${address}`,
    chainId: 4158,
    accounts: mainnetAccounts,
  },
  // Placeholder for the configuration below.
  hardhat: {
    getExplorerUrl: (address: string) => `(NO DEV EXPLORER): ${address}`,
  },
}

/**
 * Configure compiler versions in ./solhint.config.js
 *
 * @returns SolcUserConfig[]
 */
function getSolcUserConfig(): SolcUserConfig[] {
  return (solhintConfig.rules['compiler-version'][2] as string[]).map((compiler) => {
    return {
      // Adding multiple compiler versions
      // https://hardhat.org/hardhat-runner/docs/advanced/multiple-solidity-versions#multiple-solidity-versions
      version: compiler,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
      },
    }
  })
}

const config: HardhatUserConfig = {
  solidity: { compilers: getSolcUserConfig() },
  networks: {
    ...networkConfig,
    hardhat: {
      gas: 'auto',
      gasPrice: 'auto',
      forking: {
        // url: process.env.FORK_RPC || 'https://bsc.blockpi.network/v1/rpc/public',
        url: process.env.FORK_RPC || 'https://binance.llamarpc.com',
      },
    },
  },
  docgen: {
    path: './docs',
    clear: true,
    // TODO: Enable for each compile (disabled for template to avoid unnecessary generation)
    runOnCompile: false,
  },
  // typechain: {
  //   // outDir: 'src/types', // defaults to './typechain-types/'
  //   target: 'ethers-v5',
  //   // externalArtifacts: [], // optional array of glob patterns with external artifacts to process (for example external libs from node_modules)
  //   alwaysGenerateOverloads: false, // should overloads with full signatures like deposit(uint256) be generated always, even if there are no overloads?
  //   dontOverrideCompile: false, // defaults to false
  // },
  contractSizer: {
    // https://github.com/ItsNickBarry/hardhat-contract-sizer#usage
    alphaSort: false, // whether to sort results table alphabetically (default sort is by contract size)
    disambiguatePaths: false, // whether to output the full path to the compilation artifact (relative to the Hardhat root directory)
    runOnCompile: false, // whether to output contract sizes automatically after compilation
    strict: false, // whether to throw an error if any contracts exceed the size limit
    // only: [':ERC20$'], // Array of String matchers used to include contracts
    // except: [':ERC20$'], // Array of String matchers used to exclude contracts
    // outputFile: './contract-size.md', // Optional output file to write to
  },
  etherscan: {
    /**
     * // NOTE This is valid in the latest version of "@nomiclabs/hardhat-etherscan.
     *  This version breaks the src/task.ts file which hasn't been refactored yet
     */
    apiKey: {
      mainnet: getEnv('ETHERSCAN_API_KEY'),
      // optimisticEthereum: getEnv('OPTIMISTIC_ETHERSCAN_API_KEY'),
      arbitrumOne: getEnv('ARBISCAN_API_KEY'),
      bsc: getEnv('BSCSCAN_API_KEY'),
      // bscTestnet: getEnv('BSCSCAN_API_KEY'),
      polygon: getEnv('POLYGONSCAN_API_KEY'),
      // polygonTestnet: getEnv('POLYGONSCAN_API_KEY'),
      linea: getEnv('LINEASCAN_API_KEY'),
      lineaTestnet: getEnv('LINEASCAN_API_KEY'),
      lightlink: getEnv('LIGHTLINK_API_KEY'),
      base: getEnv('BASESCAN_API_KEY'),
      blast: getEnv('BLASTSCAN_API_KEY'),
      iota: getEnv('IOTASCAN_API_KEY'),
      avalanche: getEnv('AVALANCHE_API_KEY'),
      singularityTestnet: getEnv('SINGULARITYTESTNETSCAN_API_KEY'),
      crossfi: getEnv('XFISCAN_API_KEY'),
    },
    // https://hardhat.org/hardhat-runner/plugins/nomicfoundation-hardhat-verify#adding-support-for-other-networks
    customChains: [
      {
        network: 'iota',
        chainId: 8822,
        urls: {
          apiURL: 'https://explorer.evm.iota.org/api',
          browserURL: 'https://explorer.evm.iota.org/',
        },
      },
      {
        network: "linea",
        chainId: 59144,
        urls: {
          apiURL: "https://api.lineascan.build/api",
          browserURL: "https://lineascan.build/"
        }
      },
      {
        network: 'lightlink',
        chainId: 1890,
        urls: {
          apiURL: 'https://phoenix.lightlink.io/api',
          browserURL: 'https://phoenix.lightlink.io',
        },
      },
      {
        network: 'blast',
        chainId: 81457,
        urls: {
          apiURL: 'https://api.blastscan.io/api',
          browserURL: 'https://blastscan.io',
        },
      },
      {
        network: 'avalanche',
        chainId: 43114,
        urls: {
          apiURL: 'https://api.snowscan.xyz/api',
          browserURL: 'https://snowscan.xyz/',
        },
      },
      {
        network: 'singularityTestnet',
        chainId: 751,
        urls: {
          apiURL: 'https://explorer-testnet.singularityfinance.ai/api',
          browserURL: 'https://explorer-testnet.singularityfinance.ai/',
        },
      },
      {
        network: 'crossfi',
        chainId: 4158,
        urls: {
          apiURL: 'https://xfiscan.com/api/1.0/verify-contract',
          browserURL: 'https://xfiscan.com/',
        },
      },
    ]
  },
}


const parseApiKey = (network: Network, key?: string): string | undefined => {
  return key || verificationConfig.etherscan.apiKey[network]
}

/**
 * // TODO: This has been deprecated
 * Placeholder configuration for @nomiclabs/hardhat-etherscan to store verification API urls
 */
const verificationConfig: { etherscan: { apiKey: Record<Network, string> } } = {
  etherscan: {
    apiKey: {
      hardhat: 'NO_API_KEY',
      mainnet: getEnv('ETHERSCAN_API_KEY'),
      goerli: getEnv('ETHERSCAN_API_KEY'),
      arbitrum: getEnv('ARBITRUM_API_KEY'),
      arbitrumGoerli: getEnv('ARBITRUM_API_KEY'),
      bsc: getEnv('BSCSCAN_API_KEY'),
      linea: getEnv("LINEASCAN_API_KEY"),
      lineaTestnet: getEnv("LINEASCAN_API_KEY"),
      bscTestnet: getEnv('BSCSCAN_API_KEY'),
      polygon: getEnv('POLYGONSCAN_API_KEY'),
      polygonTestnet: getEnv('POLYGONSCAN_API_KEY'),
      // NOTE: I don't believe TELOS verification is supported
      telos: getEnv('TELOSSCAN_API_KEY'),
      telosTestnet: getEnv('TELOSSCAN_API_KEY_API_KEY'),
      base: getEnv('BASESCAN_API_KEY'),
      blast: getEnv('BLASTSCAN_API_KEY'),
      iota: getEnv('IOTASCAN_API_KEY'),
      lightlink: getEnv('LIGHTLINK_API_KEY'),
      avalanche: getEnv('AVALANCHE_API_KEY'),
      singularityTestnet: getEnv('SINGULARITYTESTNETSCAN_API_KEY'),
      crossfi: getEnv('XFISCAN_API_KEY'),
    },
  },
}

export default config
