/**
 * NOTE: The order of oracleTokens and oracles must match. A better approach may be to use a struct.
 */

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
      // https://docs.chain.link/data-feeds/price-feeds/addresses?network=bnb-chain
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
      wNative: '0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270',
      factoryV2: '0xCf083Be4164828f00cAE704EC15a36D711491284', // Polygon ApeSwap V2 Factory
      factoryV3: '0x1F98431c8aD98523631AE4a59f267346ea31F984', // UniswapV3 Factory: https://docs.uniswap.org/contracts/v3/reference/deployments
      stableUsdTokens: [
        '0x8f3cf7ad23cd3cadbd9735aff958023239c6a063', // DAI
        '0x2791bca1f2de4661ed88a30c99a7a9449aa84174', // USDC
        '0xc2132d05d31c914a87c6611c10748aeb04b58e8f', // USDT
      ],
      oracleTokens: [
        '0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270', // WMATIC
        '0x8f3cf7ad23cd3cadbd9735aff958023239c6a063', // DAI
        '0x2791bca1f2de4661ed88a30c99a7a9449aa84174', // USDC
        '0xc2132d05d31c914a87c6611c10748aeb04b58e8f', // USDT
      ],
      // https://docs.chain.link/data-feeds/price-feeds/addresses?network=polygon
      oracles: [
        '0xAB594600376Ec9fD91F8e885dADF0CE036862dE0', // MATIC/USD
        '0x4746DeC9e833A82EC7C2C1356372CcF2cfcD2F3D', // DAI/USD
        '0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7', // USDC/USD
        '0x0A6513e40db6EB1b165753AD52E80663aeA50545', // USDT/USD
      ],
    }
  } else if (['ethereum', 'eth'].includes(network)) {
    console.log(`Deploying with ${network} config.`)
    return {
      wNative: '',
      factoryV2: '',
      factoryV3: '',
      stableUsdTokens: [],
      oracleTokens: [],
      // https://docs.chain.link/data-feeds/price-feeds/addresses?network=ethereum
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
      // https://docs.chain.link/data-feeds/price-feeds/addresses?network=arbitrum
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
