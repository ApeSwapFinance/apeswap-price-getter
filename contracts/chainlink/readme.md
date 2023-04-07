# Chainlink Price Feeds

## Price Feed Addresses

### BSC
- BNB/USD: https://bscscan.com/address/0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE 
- BUSD/USD: https://bscscan.com/address/0xcBb98864Ef56E9042e7d2efef76141f15731B82f
- USDT/USD: https://bscscan.com/address/0xB97Ad0E74fa7d920791E90258A6E2085088b4320
- DAI/USD: https://bscscan.com/address/0x132d3C0B1D2cEa0BC552588063bdBb210FDeecfA
- USDC/USD: https://bscscan.com/address/0x51597f405303C4377E36123cBc172b13269EA163

## Using Data Feeds
https://docs.chain.link/data-feeds/using-data-feeds/

```js
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PriceConsumerV3 {
    AggregatorV3Interface internal priceFeed;

    /**
     * Network: Sepolia
     * Aggregator: BTC/USD
     * Address: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43
     */
    constructor() {
        priceFeed = AggregatorV3Interface(
            0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43
        );
    }

    /**
     * Returns the latest price.
     */
    function getLatestPrice() public view returns (int) {
        // prettier-ignore
        (
            /* uint80 roundID */,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        return price;
    }
}

```