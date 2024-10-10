/**
 * NOTE: The order of oracleTokens and oracles must match. A better approach may be to use a struct.
 */

function getNetworkConfig(network: any) {
  if (['bsc', 'bsc-fork'].includes(network)) {
    console.log(`Deploying with ${network} config.`)
    return {
      wNative: '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
      nativeLiquidityThreshold: "100000000000000000", //0.1
      factoryV2: '0x0841BD0B734E4F5853f0dD8d7Ea041c241fb0Da6',
      factoryV3: '0x7Bc382DdC5928964D7af60e7e2f6299A1eA6F48d',
      factoryAlgebra: '0x306F06C147f064A010530292A1EB6737c3e378e4',
      factorySolidly: '0xAFD89d21BdB66d00817d4153E055830B1c2B3970',
      factoryXFAI: '0x0000000000000000000000000000000000000000',
      proxyAdminContract: '',
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
      nativeLiquidityThreshold: "100" + "000000000000000000",
      // factoryV2: '0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32', // Polygon Quicskwap factory
      factoryV2: '0xCf083Be4164828f00cAE704EC15a36D711491284', // Polygon ApeSwap V2 Factory
      factoryV3: '0x1F98431c8aD98523631AE4a59f267346ea31F984', // UniswapV3 Factory: https://docs.uniswap.org/contracts/v3/reference/deployments
      factoryAlgebra: '0x411b0fAcC3489691f28ad58c47006AF5E3Ab3A28', // Algebra Factory
      factorySolidly: '0x0000000000000000000000000000000000000000',
      factoryXFAI: '0x0000000000000000000000000000000000000000',
      proxyAdminContract: '',
      stableUsdTokens: [
        '0x8f3cf7ad23cd3cadbd9735aff958023239c6a063', // DAI
        '0x2791bca1f2de4661ed88a30c99a7a9449aa84174', // USDC.e
        '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359', // USDC
        '0xc2132d05d31c914a87c6611c10748aeb04b58e8f', // USDT
      ],
      oracleTokens: [
        '0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270', // WMATIC
        '0x8f3cf7ad23cd3cadbd9735aff958023239c6a063', // DAI
        '0x2791bca1f2de4661ed88a30c99a7a9449aa84174', // USDC.e
        '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359', // USDC
        '0xc2132d05d31c914a87c6611c10748aeb04b58e8f', // USDT
      ],
      // https://docs.chain.link/data-feeds/price-feeds/addresses?network=polygon
      oracles: [
        '0xAB594600376Ec9fD91F8e885dADF0CE036862dE0', // MATIC/USD
        '0x4746DeC9e833A82EC7C2C1356372CcF2cfcD2F3D', // DAI/USD
        '0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7', // USDC.e/USD
        '0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7', // USDC/USD
        '0x0A6513e40db6EB1b165753AD52E80663aeA50545', // USDT/USD
      ],
    }
  } else if (['mainnet', 'ethereum', 'eth'].includes(network)) {
    console.log(`Deploying with ${network} config.`)
    return {
      wNative: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2', // WETH
      nativeLiquidityThreshold: "2000000000000000", //0.002
      factoryV2: '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f', // UniSwap Factory
      factoryV3: '0x1F98431c8aD98523631AE4a59f267346ea31F984', // UniswapV3 Factory
      factoryAlgebra: '0x0000000000000000000000000000000000000000', // Algebra Factory
      factorySolidly: '0x0000000000000000000000000000000000000000',
      factoryXFAI: '0x0000000000000000000000000000000000000000',
      proxyAdminContract: '',
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
      nativeLiquidityThreshold: "2000000000000000", //0.002
      factoryV2: '0xCf083Be4164828f00cAE704EC15a36D711491284',
      factoryV3: '0x1F98431c8aD98523631AE4a59f267346ea31F984',
      factoryAlgebra: '0x9C2ABD632771b433E5E7507BcaA41cA3b25D8544',
      factorySolidly: '0x0000000000000000000000000000000000000000',
      factoryXFAI: '0x0000000000000000000000000000000000000000',
      proxyAdminContract: '0x13d9Bb6623668e9bDdd8514F96E9fA707DC89C36',
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
  } else if (['linea'].includes(network)) {
    console.log(`Deploying with ${network} config.`)
    return {
      wNative: '0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f',
      nativeLiquidityThreshold: "2000000000000000", //0.002
      factoryV2: '0x9E4Fc4a5A0769ba74088856C229c4a1Db2Ea5A9e', //SpartaDex (only v2 I could find)
      factoryAlgebra: '0x622b2c98123D303ae067DB4925CD6282B3A08D0F',
      factoryV3: '0xF97a3a7187A7636F882463f6693aB82d5Be5baD4', //Nile exchange
      factorySolidly: '0xBc7695Fd00E3b32D08124b7a4287493aEE99f9ee', //Lynex
      factoryXFAI: '0xa5136eAd459F0E61C99Cec70fe8F5C24cF3ecA26', //XFAI
      proxyAdminContract: '0x7AD6115A646D225A9486DC557f17021935b99147',
      stableUsdTokens: [
        '0xA219439258ca9da29E9Cc4cE5596924745e12B93', //USDT
        '0x176211869cA2b568f2A7D4EE941E073a821EE1ff', //USDC
        '0x4AF15ec2A0BD43Db75dd04E62FAA3B8EF36b00d5', //DAI
      ],
      oracleTokens: [
        '0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f',
        '0xA219439258ca9da29E9Cc4cE5596924745e12B93', //USDT
        '0x176211869cA2b568f2A7D4EE941E073a821EE1ff', //USDC
        '0x4AF15ec2A0BD43Db75dd04E62FAA3B8EF36b00d5', //DAI
      ],
      // https://docs.chain.link/data-feeds/price-feeds/addresses?network=bnb-chain
      oracles: [
        '0x3c6Cd9Cc7c7a4c2Cf5a82734CD249D7D593354dA',
        '0xefCA2bbe0EdD0E22b2e0d2F8248E99F4bEf4A7dB',
        '0xAADAa473C1bDF7317ec07c915680Af29DeBfdCb5',
        '0x5133D67c38AFbdd02997c14Abd8d83676B4e309A',
      ],
    }
  } else if (['lightlink'].includes(network)) {
    console.log(`Deploying with ${network} config.`)
    return {
      wNative: '0x7EbeF2A4b1B09381Ec5B9dF8C5c6f2dBECA59c73',
      nativeLiquidityThreshold: "2000000000000000", //0.002
      factoryV2: '0x0000000000000000000000000000000000000000', //
      factoryAlgebra: '0x0000000000000000000000000000000000000000',
      factoryV3: '0xEE6099234bbdC793a43676D98Eb6B589ca7112D7', // elektrik
      factorySolidly: '0x0000000000000000000000000000000000000000', //
      factoryXFAI: '0x0000000000000000000000000000000000000000', //
      proxyAdminContract: '',
      stableUsdTokens: [
        '0x6308fa9545126237158778e74AE1b6b89022C5c0', //USDT
        '0x18fB38404DADeE1727Be4b805c5b242B5413Fa40', //USDC
        '0x49F65C3FfC6e45104ff5cB00e6030C626157a90b', //DAI
      ],
      oracleTokens: [
      ],
      // https://docs.chain.link/data-feeds/price-feeds/addresses?network=bnb-chain
      oracles: [
      ],
    }
  }
  else if (['iota'].includes(network)) {
    console.log(`Deploying with ${network} config.`)
    return {
      wNative: '0x6e47f8d48a01b44DF3fFF35d258A10A3AEdC114c',
      nativeLiquidityThreshold: "55000000000000000000", //55
      factoryV2: '0x349aaAc3a500014981CBA11b64C76c66a6c1e8D0', //MagicSea
      factoryAlgebra: '0x0000000000000000000000000000000000000000',
      factoryV3: '0x0000000000000000000000000000000000000000', // 
      factorySolidly: '0x0000000000000000000000000000000000000000', //
      factoryXFAI: '0x0000000000000000000000000000000000000000', //
      proxyAdminContract: '',
      stableUsdTokens: [
        '0xC1B8045A6ef2934Cf0f78B0dbD489969Fa9Be7E4', //USDT
        '0xFbDa5F676cB37624f28265A144A48B0d6e87d3b6', //USDC
      ],
      oracleTokens: [
      ],
      // https://docs.chain.link/data-feeds/price-feeds/addresses?network=bnb-chain
      oracles: [
      ],
    }
  }
  else if (['base'].includes(network)) {
    console.log(`Deploying with ${network} config.`)
    return {
      wNative: '0x4200000000000000000000000000000000000006',
      nativeLiquidityThreshold: "2000000000000000", //0.002
      factoryV2: '0x4bd16d59A5E1E0DB903F724aa9d721a31d7D720D', // Synthswap
      factoryAlgebra: '0xa37359E63D1aa44C0ACb2a4605D3B45785C97eE3', // Synthswap
      factoryV3: '0x33128a8fC17869897dcE68Ed026d694621f6FDfD', //UniswapV3 
      factorySolidly: '0x420DD381b31aEf6683db6B902084cB0FFECe40Da', //  Aerodrome
      factoryXFAI: '0x0000000000000000000000000000000000000000', //
      proxyAdminContract: '0x218eb9acdc721e235969a30f5da46fb1224fa7a7',
      stableUsdTokens: [
        '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913', //USDC
        '0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb', //DAI
        '0xB79DD08EA68A908A97220C76d19A6aA9cBDE4376' //USD+
      ],
      oracleTokens: [
        "0x4200000000000000000000000000000000000006",
        "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
        "0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb"
      ],
      // https://docs.chain.link/data-feeds/price-feeds/addresses?network=bnb-chain
      oracles: [
        "0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70",
        "0x7e860098F58bBFC8648a4311b374B1D669a2bc6B",
        "0x591e79239a7d679378eC8c847e5038150364C78F",
      ],
    }
  } else if (['telos'].includes(network)) {
    console.log(`Deploying with ${network} config.`)
    return {
      wNative: '',
      nativeLiquidityThreshold: "",
      factoryV2: '',
      factoryV3: '',
      factoryAlgebra: '',
      factorySolidly: '',
      factoryXFAI: '',
      stableUsdTokens: [],
      oracleTokens: [],
      oracles: [],
    }
  } else {
    throw new Error(`No config found for network ${network}.`)
  }
}

export default getNetworkConfig
