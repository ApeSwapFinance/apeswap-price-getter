import { mine, time, loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { expect } from 'chai'
import { ethers } from 'hardhat'
import axios from 'axios'
import { BigNumber } from 'ethers'
import { deployPriceGetterBSCFixture } from './fixtures/deployPriceGetter'
import { estimateReadOperationGas } from './utils/gasHelper'

enum Protocol {
  __,
  Both,
  V2,
  V3,
}

describe('PriceGetter', function () {
  async function fixture() {
    const priceGetterFixture = await deployPriceGetterBSCFixture(ethers)
    return { ...priceGetterFixture }
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

    const functionName = 'getNativePrice'
    const wnativePrice = await priceGetter[functionName](Protocol.Both)
    const gasUsage = await estimateReadOperationGas(priceGetter, functionName, [Protocol.Both])
    console.log(`Gas usage for ${functionName}:`, gasUsage.toString())

    const url = `https://api.coingecko.com/api/v3/simple/price?ids=binancecoin&vs_currencies=usd&precision=18`
    const coingeckoData: any = await axios.get(url)
    const coingeckoPrice = coingeckoData.data.binancecoin.usd
    const coingeckoPriceBN = BigNumber.from(Math.floor(coingeckoPrice * 1e9)).mul(1e9)
    expect(wnativePrice).to.be.within(coingeckoPriceBN.mul(99).div(100), coingeckoPriceBN.mul(101).div(100))
  })

  it('Should get right native price from custom factory', async function () {
    const { priceGetter, pcsFactoryV2, pcsFactoryV3 } = await loadFixture(fixture)

    const functionName = 'getNativePriceFromFactory'
    const wnativePrice = await priceGetter[functionName](Protocol.Both, pcsFactoryV2, pcsFactoryV3)
    const gasUsage = await estimateReadOperationGas(priceGetter, functionName, [
      Protocol.Both,
      pcsFactoryV2,
      pcsFactoryV3,
    ])
    console.log(`Gas usage for ${functionName}:`, gasUsage.toString())

    const url = `https://api.coingecko.com/api/v3/simple/price?ids=binancecoin&vs_currencies=usd&precision=18`
    const coingeckoData: any = await axios.get(url)
    const coingeckoPrice = coingeckoData.data.binancecoin.usd
    const coingeckoPriceBN = BigNumber.from(Math.floor(coingeckoPrice * 1e9)).mul(1e9)
    expect(wnativePrice).to.be.within(coingeckoPriceBN.mul(99).div(100), coingeckoPriceBN.mul(101).div(100))
  })

  it('Should get right token prices', async function () {
    //Prices are allowed to be 2% off from coingecko price API
    const { priceGetter, tokens } = await loadFixture(fixture)
    const tokenAddresses = Array.from(tokens, (x) => x.address)

    const functionName = 'getPrices'
    const tokenPrices = await priceGetter[functionName](tokenAddresses, Protocol.Both)
    const gasUsage = await estimateReadOperationGas(priceGetter, functionName, [tokenAddresses, Protocol.Both])
    console.log(`Gas usage for ${functionName}:`, gasUsage.toString())

    const tokenNames = Array.from(tokens, (x) => x.coingeckoId)
    const url = `https://api.coingecko.com/api/v3/simple/price?ids=${tokenNames.toString()}&vs_currencies=usd&precision=18`
    const coingeckoData: any = await axios.get(url)
    for (let i = 0; i < tokenPrices.length; i++) {
      const coingeckoPrice = coingeckoData.data[tokenNames[i]].usd
      const coingeckoPriceBN = BigNumber.from(Math.floor(coingeckoPrice * 1e9)).mul(1e9)
      if (!tokenPrices[i].eq(0)) {
        expect(tokenPrices[i]).to.be.within(coingeckoPriceBN.mul(98).div(100), coingeckoPriceBN.mul(102).div(100))
      }
    }
  })

  it('Should get right token prices with custom factory', async function () {
    //Prices are allowed to be 2% off from coingecko price API
    const { priceGetter, tokens, factoryV2, factoryV3, pcsFactoryV2, pcsFactoryV3 } = await loadFixture(fixture)
    const tokenAddresses = Array.from(tokens, (x) => x.address)

    const functionName = 'getPricesFromFactory'
    const tokenPrices = await priceGetter[functionName](tokenAddresses, Protocol.Both, pcsFactoryV2, pcsFactoryV3)
    const gasUsage = await estimateReadOperationGas(priceGetter, functionName, [
      tokenAddresses,
      Protocol.Both,
      pcsFactoryV2,
      pcsFactoryV3,
    ])
    console.log(`Gas usage for ${functionName}:`, gasUsage.toString())

    const tokenNames = Array.from(tokens, (x) => x.coingeckoId)
    const url = `https://api.coingecko.com/api/v3/simple/price?ids=${tokenNames.toString()}&vs_currencies=usd&precision=18`
    const coingeckoData: any = await axios.get(url)
    for (let i = 0; i < tokenPrices.length; i++) {
      const coingeckoPrice = coingeckoData.data[tokenNames[i]].usd
      const coingeckoPriceBN = BigNumber.from(Math.floor(coingeckoPrice * 1e9)).mul(1e9)
      if (!tokenPrices[i].eq(0)) {
        expect(tokenPrices[i]).to.be.within(coingeckoPriceBN.mul(98).div(100), coingeckoPriceBN.mul(102).div(100))
      }
    }
  })
})
