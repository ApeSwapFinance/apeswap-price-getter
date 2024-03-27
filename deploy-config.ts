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
      factoryAlgebra: '0x306F06C147f064A010530292A1EB6737c3e378e4',
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
      // factoryV2: '0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32', // Polygon Quicskwap factory
      factoryV2: '0xCf083Be4164828f00cAE704EC15a36D711491284', // Polygon ApeSwap V2 Factory
      factoryV3: '0x1F98431c8aD98523631AE4a59f267346ea31F984', // UniswapV3 Factory: https://docs.uniswap.org/contracts/v3/reference/deployments
      factoryAlgebra: '0x411b0fAcC3489691f28ad58c47006AF5E3Ab3A28', // Algebra Factory
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
  } else if (['mainnet', 'ethereum', 'eth'].includes(network)) {
    console.log(`Deploying with ${network} config.`)
    return {
      wNative: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2', // WETH
      factoryV2: '0xBAe5dc9B19004883d0377419FeF3c2C8832d7d7B', // ApeFactory
      factoryV3: '0x1F98431c8aD98523631AE4a59f267346ea31F984', // UniswapV3 Factory
      factoryAlgebra: '', // Algebra Factory
      stableUsdTokens: [
        '0x6B175474E89094C44Da98b954EedeAC495271d0F', // DAI
        '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', // USDC
        '0xdAC17F958D2ee523a2206206994597C13D831ec7', // USDT
      ],
      oracleTokens: [
        '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2', // WETH
        '0x6B175474E89094C44Da98b954EedeAC495271d0F', // DAI
        '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', // USDC
        '0xdAC17F958D2ee523a2206206994597C13D831ec7', // USDT
      ],
      // https://docs.chain.link/data-feeds/price-feeds/addresses?network=ethereum
      oracles: [
        '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419', // ETH/USD
        '0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9', // DAI/USD
        '0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6', // USDC/USD
        '0x3E7d1eAB13ad0104d2750B8863b489D65364e32D', // USDT/USD
      ],
    }
  } else if (['arbitrum'].includes(network)) {
    console.log(`Deploying with ${network} config.`)
    return {
      wNative: '0x82af49447d8a07e3bd95bd0d56f35241523fbab1', // WETH
      factoryV2: '0xCf083Be4164828f00cAE704EC15a36D711491284',
      factoryV3: '0x1F98431c8aD98523631AE4a59f267346ea31F984',
      factoryAlgebra: '0x9C2ABD632771b433E5E7507BcaA41cA3b25D8544',
      stableUsdTokens: [
        '0xda10009cbd5d07dd0cecc66161fc93d7c9000da1', // DAI
        '0xff970a61a04b1ca14834a43f5de4533ebddb5cc8', // USDC
        '0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9', // USDT
      ],
      oracleTokens: [
        '0x82af49447d8a07e3bd95bd0d56f35241523fbab1', // WETH
        '0xda10009cbd5d07dd0cecc66161fc93d7c9000da1', // DAI
        '0xff970a61a04b1ca14834a43f5de4533ebddb5cc8', // USDC
        '0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9', // USDT
      ],
      // https://docs.chain.link/data-feeds/price-feeds/addresses?network=arbitrum
      oracles: [
        '0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612', // ETH/USD
        '0xc5C8E77B397E531B8EC06BFb0048328B30E9eCfB', // DAI/USD
        '0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3', // USDC/USD
        '0x3f3f5dF88dC9F13eac63DF89EC16ef6e7E25DdE7', // USDT/USD
      ],
    }
  } else if (['telos'].includes(network)) {
    console.log(`Deploying with ${network} config.`)
    return {
      wNative: '',
      factoryV2: '',
      factoryV3: '',
      factoryAlgebra: '',
      stableUsdTokens: [],
      oracleTokens: [],
      oracles: [],
    }
  } else {
    throw new Error(`No config found for network ${network}.`)
  }
}

export default getNetworkConfig
