import { mine, time, loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { expect } from 'chai'
import { ethers } from 'hardhat'
import axios from 'axios'
import { BigNumber } from 'ethers'

enum Protocol {
  __,
  Both,
  V2,
  V3,
}

describe('PriceGetter', function () {
  async function fixture() {
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

    const PriceGetter = await ethers.getContractFactory('PriceGetterV2')
    const priceGetter = await PriceGetter.deploy(wNative, factoryV2, factoryV3, stableUsdTokens, oracleTokens, oracles)
    const tokens = [
      { address: '0x603c7f932ED1fc6575303D8Fb018fDCBb0f39a95', coingeckoId: 'apeswap-finance' },
      { address: '0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d', coingeckoId: 'usd-coin' },
      { address: '0xbA2aE424d960c26247Dd6c32edC70B295c744C43', coingeckoId: 'dogecoin' },
      { address: '0x5774b2fc3e91af89f89141eacf76545e74265982', coingeckoId: 'nfty-token' },
      { address: '0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c', coingeckoId: 'bitcoin' },
    ]
    return { priceGetter, tokens, factoryV2, factoryV3, pcsFactoryV2, pcsFactoryV3 }
  }

  it('Should remove and add oracle', async function () {
    const { priceGetter } = await loadFixture(fixture)
    await priceGetter.removeTokenOracle('0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56')
    await priceGetter.setTokenOracle(
      '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56',
      '0x0567f2323251f0aab15c8dfb1967e4e8a7d42aee',
      1
    )
  })

  it('Should get right native price', async function () {
    const { priceGetter } = await loadFixture(fixture)
    const wnativePrice = await priceGetter.getNativePrice(Protocol.Both)
    const url = `https://api.coingecko.com/api/v3/simple/price?ids=binancecoin&vs_currencies=usd&precision=18`
    const coingeckoData: any = await axios.get(url)
    const coingeckoPrice = coingeckoData.data.binancecoin.usd
    const coingeckoPriceBN = BigNumber.from(Math.floor(coingeckoPrice * 1e9)).mul(1e9)
    expect(wnativePrice).to.be.within(coingeckoPriceBN.mul(99).div(100), coingeckoPriceBN.mul(101).div(100))
  })

  it('Should get right native price from custom factory', async function () {
    const { priceGetter, pcsFactoryV2, pcsFactoryV3 } = await loadFixture(fixture)
    const wnativePrice = await priceGetter.getNativePriceFromFactory(Protocol.Both, pcsFactoryV2, pcsFactoryV3)
    const url = `https://api.coingecko.com/api/v3/simple/price?ids=binancecoin&vs_currencies=usd&precision=18`
    const coingeckoData: any = await axios.get(url)
    const coingeckoPrice = coingeckoData.data.binancecoin.usd
    const coingeckoPriceBN = BigNumber.from(Math.floor(coingeckoPrice * 1e9)).mul(1e9)
    expect(wnativePrice).to.be.within(coingeckoPriceBN.mul(99).div(100), coingeckoPriceBN.mul(101).div(100))
  })

  it('Should get right token prices', async function () {
    //Prices are allowed to be 1% off from coingecko price API
    const { priceGetter, tokens } = await loadFixture(fixture)
    const tokenAddresses = Array.from(tokens, (x) => x.address)
    const tokenPrices = await priceGetter.getPrices(tokenAddresses, Protocol.Both)
    const tokenNames = Array.from(tokens, (x) => x.coingeckoId)
    const url = `https://api.coingecko.com/api/v3/simple/price?ids=${tokenNames.toString()}&vs_currencies=usd&precision=18`
    const coingeckoData: any = await axios.get(url)
    for (let i = 0; i < tokenPrices.length; i++) {
      console.log(i)
      const coingeckoPrice = coingeckoData.data[tokenNames[i]].usd
      const coingeckoPriceBN = BigNumber.from(Math.floor(coingeckoPrice * 1e9)).mul(1e9)
      if (!tokenPrices[i].eq(0)) {
        expect(tokenPrices[i]).to.be.within(coingeckoPriceBN.mul(99).div(100), coingeckoPriceBN.mul(101).div(100))
      }
    }
  })

  it('Should get right token prices with custom factory', async function () {
    //Prices are allowed to be 1% off from coingecko price API
    const { priceGetter, tokens, factoryV2, factoryV3, pcsFactoryV2, pcsFactoryV3 } = await loadFixture(fixture)
    const tokenAddresses = Array.from(tokens, (x) => x.address)
    const tokenPrices = await priceGetter.getPricesFromFactory(
      tokenAddresses,
      Protocol.Both,
      pcsFactoryV2,
      pcsFactoryV3
    )
    const tokenNames = Array.from(tokens, (x) => x.coingeckoId)
    const url = `https://api.coingecko.com/api/v3/simple/price?ids=${tokenNames.toString()}&vs_currencies=usd&precision=18`
    const coingeckoData: any = await axios.get(url)
    for (let i = 0; i < tokenPrices.length; i++) {
      const coingeckoPrice = coingeckoData.data[tokenNames[i]].usd
      const coingeckoPriceBN = BigNumber.from(Math.floor(coingeckoPrice * 1e9)).mul(1e9)
      if (!tokenPrices[i].eq(0)) {
        expect(tokenPrices[i]).to.be.within(coingeckoPriceBN.mul(99).div(100), coingeckoPriceBN.mul(101).div(100))
      }
    }
  })
})
