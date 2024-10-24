// test/jsoncompare.spec.ts

import * as fs from 'fs';
import * as path from 'path';
import axios from 'axios';

describe('JSON Comparison', () => {
    it('should log a warning for mismatched', async () => {
        const json1 = await axios.get('https://realtime-api.ape.bond/bonds')
        const json2 = await axios.get('http://localhost:4001/bonds')
        console.log(json1.data.bonds.length, json2.data.bonds.length)

        const filteredJson1 = json1.data.bonds.filter(item => (item.chainId === 56 && item.showcaseTokenName !== "HAT"));
        const filteredJson2 = json2.data.bonds.filter(item => (item.chainId === 56 && item.showcaseTokenName !== "HAT"));
        console.log(filteredJson1.length, filteredJson2.length)

        filteredJson1.forEach((item1, index) => {
            const item2 = filteredJson2[index];
            if (Number(item1.principalTokenPrice) !== Number(item2.principalTokenPrice)) {
                const priceDifference = ((Number(item1.principalTokenPrice) - Number(item2.principalTokenPrice)) / Number(item2.principalTokenPrice)) * 100;
                console.warn(`principalTokenPrice ${index}: ${item1.principalTokenName} ${item2.principalTokenName} ${item1.principalTokenPrice} !== ${item2.principalTokenPrice} (Difference: ${priceDifference.toFixed(2)}%)`);
            }
            if (item1.payoutTokenPrice !== item2.payoutTokenPrice) {
                const priceDifference = ((Number(item1.payoutTokenPrice) - Number(item2.payoutTokenPrice)) / Number(item2.payoutTokenPrice)) * 100;
                console.warn(`payoutTokenPrice ${index}: ${item1.payoutTokenName} ${item2.payoutTokenName} ${item1.payoutTokenPrice} !== ${item2.payoutTokenPrice} (Difference: ${priceDifference.toFixed(2)}%)`);
            }
        });
    });
});