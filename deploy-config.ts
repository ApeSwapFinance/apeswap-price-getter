function getNetworkConfig(network: any) {
  if (['bsc', 'bsc-fork'].includes(network)) {
    console.log(`Deploying with ${network} config.`)
    return {
      wNative: '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
      factoryV2: '0x0841BD0B734E4F5853f0dD8d7Ea041c241fb0Da6',
      factoryV3: '0x7Bc382DdC5928964D7af60e7e2f6299A1eA6F48d',
      stableUsdTokens: [
        '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56',
        '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d',
        '0x55d398326f99059fF775485246999027B3197955',
      ],
      oracleTokens: [
        '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
        '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56',
        '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d',
        '0x55d398326f99059fF775485246999027B3197955',
      ],
      oracles: [
        '0x0567f2323251f0aab15c8dfb1967e4e8a7d42aee',
        '0xcbb98864ef56e9042e7d2efef76141f15731b82f',
        '0x51597f405303c4377e36123cbc172b13269ea163',
        '0xb97ad0e74fa7d920791e90258a6e2085088b4320',
      ],
    }
  } else if (['polygon'].includes(network)) {
    console.log(`Deploying with ${network} config.`)
    return {
      wNative: '',
      factoryV2: '',
      factoryV3: '',
      stableUsdTokens: [],
      oracleTokens: [],
      oracles: [],
    }
  } else if (['ethereum', 'eth'].includes(network)) {
    console.log(`Deploying with ${network} config.`)
    return {
      wNative: '',
      factoryV2: '',
      factoryV3: '',
      stableUsdTokens: [],
      oracleTokens: [],
      oracles: [],
    }
  } else if (['arbitrum'].includes(network)) {
    console.log(`Deploying with ${network} config.`)
    return {
      wNative: '',
      factoryV2: '',
      factoryV3: '',
      stableUsdTokens: [],
      oracleTokens: [],
      oracles: [],
    }
  } else if (['telos'].includes(network)) {
    console.log(`Deploying with ${network} config.`)
    return {
      wNative: '',
      factoryV2: '',
      factoryV3: '',
      stableUsdTokens: [],
      oracleTokens: [],
      oracles: [],
    }
  } else {
    throw new Error(`No config found for network ${network}.`)
  }
}

export default getNetworkConfig
