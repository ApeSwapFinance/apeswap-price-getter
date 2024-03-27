import { ethers } from 'hardhat'

export async function deployPriceGetterBSCFixture(_ethers: typeof ethers) {
  const wNative = '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c'
  const stableUsdTokens: string[] = [
    '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56',
    '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d',
    '0x55d398326f99059fF775485246999027B3197955',
  ]
  const oracleTokens: string[] = [
    '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
    '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56',
    '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d',
    '0x55d398326f99059fF775485246999027B3197955',
  ]
  const oracles: string[] = [
    '0x0567f2323251f0aab15c8dfb1967e4e8a7d42aee',
    '0xcbb98864ef56e9042e7d2efef76141f15731b82f',
    '0x51597f405303c4377e36123cbc172b13269ea163',
    '0xb97ad0e74fa7d920791e90258a6e2085088b4320',
  ]
  const factoryV2 = '0x0841BD0B734E4F5853f0dD8d7Ea041c241fb0Da6'
  const factoryV3 = '0x7Bc382DdC5928964D7af60e7e2f6299A1eA6F48d'

  const pcsFactoryV2 = '0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73'
  const pcsFactoryV3 = '0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865'

  const algebraFactory = '0x306F06C147f064A010530292A1EB6737c3e378e4'

  const PriceGetter = await ethers.getContractFactory('PriceGetterV2')
  const priceGetter = await PriceGetter.deploy()
  await priceGetter.initialize(wNative, factoryV2, factoryV3, algebraFactory, stableUsdTokens, oracleTokens, oracles)
  const tokens = [
    { address: '0x603c7f932ED1fc6575303D8Fb018fDCBb0f39a95', coingeckoId: 'apeswap-finance' },
    { address: '0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d', coingeckoId: 'usd-coin' },
    { address: '0xbA2aE424d960c26247Dd6c32edC70B295c744C43', coingeckoId: 'dogecoin' },
    { address: '0x5774b2fc3e91af89f89141eacf76545e74265982', coingeckoId: 'nfty-token' },
    { address: '0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c', coingeckoId: 'bitcoin' },
  ]
  return { priceGetter, tokens, factoryV2, factoryV3, pcsFactoryV2, pcsFactoryV3, algebraFactory }
}
