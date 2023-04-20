// // SPDX-License-Identifier: MIT
// pragma solidity 0.7.6;

// import "./interfaces/IApePair.sol";
// import "./interfaces/IArrakisVaultV1.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
// import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
// import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
// import "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";
// import "@uniswap/v3-core/contracts/libraries/FullMath.sol";
// import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

// // This library provides simple price calculations for ApeSwap tokens, accounting
// // for commonly used pairings. Will break if USDT, USDC, or DAI goes far off peg.
// // Should NOT be used as the sole oracle for sensitive calculations such as
// // liquidation, as it is vulnerable to manipulation by flash loans, etc. BETA
// // SOFTWARE, PROVIDED AS IS WITH NO WARRANTIES WHATSOEVER.

// // UNIV3 ETH ApeSwap only version

// contract UniV2AndV3PriceGetter {
//     enum Protocol {
//         _,
//         Both,
//         V2,
//         V3
//     }

//     address public constant FACTORYV2 = 0xCf083Be4164828f00cAE704EC15a36D711491284; //FactoryV2
//     bytes32 public constant INITCODEHASHV2 = hex"511f0f358fe530cda0859ec20becf391718fdf5a329be02f4c95361f3d6a42d8";

//     address public constant FACTORYV3 = 0x86A2Ad3771ed3b4722238CEF303048AC44231987; //FactoryV3
//     bytes32 public constant INITCODEHASHV3 = hex"a598dd2fba360510c5a8f02f44423a4468e902df5857dbce3ca162a43a3a31ff";

//     //All returned prices calculated with this precision (18 decimals)
//     uint256 private constant PRECISION = 10**DECIMALS; //1e18 == $1
//     uint256 public constant DECIMALS = 18;
//     uint256 private constant USDC_RAW_PRICE = 1e6;
//     uint256 private constant USDT_RAW_PRICE = 1e6;

//     //Token addresses
//     address constant WETH = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
//     address constant USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
//     address constant USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
//     address constant DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;

//     //returns the price of any token in USD based on common pairings; zero on failure
//     function getPrice(address token, uint32 secondsAgo) public view returns (uint256) {
//         return getPrice(token, secondsAgo, Protocol.Both);
//     }

//     function getPrice(
//         address token,
//         uint32 secondsAgo,
//         Protocol version
//     ) public view returns (uint256) {
//         uint256 ETHPrice = getETHPrice(secondsAgo, version);
//         uint256 pegPrice = pegTokenPrice(token, ETHPrice);
//         if (pegPrice != 0) return pegPrice;

//         return _getPrice(token, ETHPrice, secondsAgo, version);
//     }

//     //returns the price of an LP token. token0/token1 price; zero on failure
//     function getLPPrice(
//         address token0,
//         address token1,
//         uint24 fee,
//         uint32 secondsAgo
//     ) public view returns (uint256) {
//         return pairTokensAndValue(token0, token1, fee, secondsAgo);
//     }

//     function getLPPrice(address token, uint256 _decimals) external view returns (uint256) {
//         return normalize(getRawLPPrice(token), token, _decimals);
//     }

//     // returns the prices of multiple tokens, zero on failure
//     function getPrices(
//         address[] memory tokens,
//         uint32 secondsAgo,
//         Protocol version
//     ) public view returns (uint256[] memory prices) {
//         prices = new uint256[](tokens.length);
//         uint256 ethPrice = getETHPrice(secondsAgo, version);

//         for (uint256 i; i < prices.length; i++) {
//             address token = tokens[i];
//             uint256 pegPrice = pegTokenPrice(token, ethPrice);

//             if (pegPrice != 0) prices[i] = pegPrice;
//             else prices[i] = _getPrice(token, ethPrice, secondsAgo, version);
//         }
//     }

//     function getLPPrices(address[] calldata tokens, uint256 _decimals) external view returns (uint256[] memory prices) {
//         prices = getRawLPPrices(tokens);

//         for (uint256 i; i < prices.length; i++) {
//             prices[i] = normalize(prices[i], tokens[i], _decimals);
//         }
//     }

//     //returns the value of a LP token if it is one, or the regular price if it isn't LP
//     function getRawLPPrice(address token) internal view returns (uint256) {
//         uint256 pegPrice = pegTokenPriceV2(token);
//         if (pegPrice != 0) return pegPrice;

//         (uint256 ethPrice, ) = getETHPriceV2();
//         return getRawLPPrice(token, ethPrice);
//     }

//     //returns the prices of multiple tokens which may or may not be LPs
//     function getRawLPPrices(address[] memory tokens) internal view returns (uint256[] memory prices) {
//         prices = new uint256[](tokens.length);
//         (uint256 ethPrice, ) = getETHPriceV2();

//         for (uint256 i; i < prices.length; i++) {
//             address token = tokens[i];
//             uint256 pegPrice = pegTokenPrice(token, ethPrice);

//             if (pegPrice != 0) prices[i] = pegPrice;
//             else prices[i] = getRawLPPrice(token, ethPrice);
//         }
//     }

//     //Calculate LP token value in USD. Generally compatible with any UniswapV2 pair but will always price underlying
//     //tokens using ape prices. If the provided token is not a LP, it will attempt to price the token as a
//     //standard token. This is useful for MasterChef farms which stake both single tokens and pairs
//     function getRawLPPrice(address lp, uint256 bnbPrice) internal view returns (uint256) {
//         //if not a LP, handle as a standard token
//         try IApePair(lp).getReserves() returns (uint112 reserve0, uint112 reserve1, uint32) {
//             address token0 = IApePair(lp).token0();
//             address token1 = IApePair(lp).token1();
//             uint256 totalSupply = IApePair(lp).totalSupply();

//             //price0*reserve0+price1*reserve1
//             (uint256 token0Price, ) = _getPriceV2(token0, bnbPrice, true);
//             (uint256 token1Price, ) = _getPriceV2(token1, bnbPrice, true);

//             uint256 totalValue = token0Price * reserve0 + token1Price * reserve1;

//             return totalValue / totalSupply;
//         } catch {
//             (uint256 LPPrice, ) = _getPriceV2(lp, bnbPrice, true);
//             return LPPrice;
//         }
//     }

//     function getETHPrice(uint32 secondsAgo) public view returns (uint256 ethPrice) {
//         return getETHPrice(secondsAgo, Protocol.Both);
//     }

//     function getETHPrice(uint32 secondsAgo, Protocol version) public view returns (uint256 ethPrice) {
//         if (version == Protocol.Both) {
//             (uint256 ETHV3Price, uint256 totalETHV3) = getETHPriceV3(secondsAgo);
//             (uint256 ETHV2Price, uint256 totalETHV2) = getETHPriceV2();
//             if (totalETHV3 + totalETHV2 == 0) return 0;
//             return (ETHV3Price * totalETHV3 + ETHV2Price * totalETHV2) / (totalETHV3 + totalETHV2);
//         } else if (version == Protocol.V2) {
//             (uint256 ETHV2Price, ) = getETHPriceV2();
//             return ETHV2Price;
//         } else if (version == Protocol.V3) {
//             (uint256 ETHV3Price, ) = getETHPriceV3(secondsAgo);
//             return ETHV3Price;
//         } else {
//             revert("Invalid protocol");
//         }
//     }

//     //returns the current USD price of BNB based on primary stablecoin pairs
//     function getETHPriceV2() public view returns (uint256 price, uint256 wethTotal) {
//         (uint256 wbnbReserve0, uint256 daiReserve, ) = IApePair(pairFor(WETH, DAI)).getReserves();
//         if (DAI < WETH) (wbnbReserve0, daiReserve) = (daiReserve, wbnbReserve0);
//         (uint256 wbnbReserve1, uint256 udscReserve, ) = IApePair(pairFor(WETH, USDC)).getReserves();
//         if (USDC < WETH) (wbnbReserve1, udscReserve) = (udscReserve, wbnbReserve1);
//         (uint256 wbnbReserve2, uint256 usdtReserve, ) = IApePair(pairFor(WETH, USDT)).getReserves();
//         if (USDT < WETH) (wbnbReserve2, usdtReserve) = (usdtReserve, wbnbReserve2);

//         wethTotal = wbnbReserve0 + wbnbReserve1 + wbnbReserve2;
//         uint256 usdTotal = daiReserve +
//             ((udscReserve * PRECISION) / USDC_RAW_PRICE) +
//             ((usdtReserve * PRECISION) / USDT_RAW_PRICE);

//         price = (usdTotal * PRECISION) / wethTotal;
//     }

//     //returns the current USD price of ETH based on primary stablecoin pairs
//     function getETHPriceV3(uint32 secondsAgo) public view returns (uint256 ethPrice, uint256 totalBalance) {
//         uint256 price;
//         uint256 totalPrice;

//         uint24[] memory fees = new uint24[](4);
//         fees[0] = 100;
//         fees[1] = 500;
//         fees[2] = 3000;
//         fees[3] = 10000;
//         for (uint24 feeIndex = 0; feeIndex < 4; feeIndex++) {
//             uint24 fee = fees[feeIndex];
//             price = pairTokensAndValue(WETH, DAI, fee, secondsAgo);
//             if (price > 0) {
//                 address pair = pairFor(WETH, DAI, fee);
//                 uint256 balance = IERC20(WETH).balanceOf(pair);
//                 totalPrice += price * balance;
//                 totalBalance += balance;
//             }

//             price = pairTokensAndValue(WETH, USDC, fee, secondsAgo);
//             if (price > 0) {
//                 address pair = pairFor(WETH, USDC, fee);
//                 uint256 balance = IERC20(WETH).balanceOf(pair);
//                 totalPrice += price * balance;
//                 totalBalance += balance;
//             }

//             price = pairTokensAndValue(WETH, USDT, fee, secondsAgo);
//             if (price > 0) {
//                 address pair = pairFor(WETH, USDT, fee);
//                 uint256 balance = IERC20(WETH).balanceOf(pair);
//                 totalPrice += price * balance;
//                 totalBalance += balance;
//             }
//         }

//         if (totalBalance == 0) {
//             return (0, totalBalance);
//         }
//         ethPrice = totalPrice / totalBalance;
//     }

//     function getArrakisPrice(IArrakisVaultV1 _token, uint32 secondsAgo) external view returns (uint256) {
//         address token0 = _token.token0();
//         address token1 = _token.token1();
//         uint256 price0 = getPrice(token0, secondsAgo, Protocol.V3);
//         uint256 price1 = getPrice(token1, secondsAgo, Protocol.V3);
//         (uint256 underlying0, uint256 underlying1) = _token.getUnderlyingBalances();
//         uint256 totalSupply = _token.totalSupply();

//         try ERC20(token0).decimals() returns (uint8 dec0) {
//             underlying0 = underlying0 * 10**(18 - dec0);
//         } catch {}

//         try ERC20(token1).decimals() returns (uint8 dec1) {
//             underlying1 = underlying1 * 10**(18 - dec1);
//         } catch {}

//         return (price0 * underlying0 + price1 * underlying1) / totalSupply;
//     }

//     function _getPrice(
//         address token,
//         uint256 ethPrice,
//         uint32 secondsAgo,
//         Protocol version
//     ) internal view returns (uint256 rawPrice) {
//         if (version == Protocol.Both) {
//             (uint256 ETHV3Price, uint256 totalETHV3) = _getPriceV3(token, ethPrice, secondsAgo);
//             (uint256 ETHV2Price, uint256 totalETHV2) = _getPriceV2(token, ethPrice, false);
//             return (ETHV3Price * totalETHV3 + ETHV2Price * totalETHV2) / (totalETHV3 + totalETHV2);
//         } else if (version == Protocol.V2) {
//             (uint256 ETHV2Price, ) = _getPriceV2(token, ethPrice, false);
//             return ETHV2Price;
//         } else if (version == Protocol.V3) {
//             (uint256 ETHV3Price, ) = _getPriceV3(token, ethPrice, secondsAgo);
//             return ETHV3Price;
//         } else {
//             revert("Invalid protocol");
//         }
//     }

//     // checks for primary tokens and returns the correct predetermined price if possible, otherwise calculates price
//     function _getPriceV2(
//         address token,
//         uint256 ethPrice,
//         bool raw
//     ) internal view returns (uint256 price, uint256 numTokens) {
//         uint256 pegPrice = pegTokenPriceV2(token, ethPrice);

//         if (pegPrice != 0) return (pegPrice, 1);

//         uint256 pairedValue;
//         uint256 lpTokens;
//         uint256 lpValue;

//         (lpTokens, lpValue) = pairTokensAndValue(token, WETH);
//         numTokens += lpTokens;
//         pairedValue += lpValue;

//         (lpTokens, lpValue) = pairTokensAndValue(token, DAI);
//         numTokens += lpTokens;
//         pairedValue += lpValue;

//         (lpTokens, lpValue) = pairTokensAndValue(token, USDC);
//         numTokens += lpTokens;
//         pairedValue += lpValue;

//         (lpTokens, lpValue) = pairTokensAndValue(token, USDT);
//         numTokens += lpTokens;
//         pairedValue += lpValue;

//         if (numTokens > 0) {
//             price = pairedValue / numTokens;
//             if (!raw) price = normalize(price, token, 18);
//         }
//     }

//     // checks for primary tokens and returns the correct predetermined price if possible, otherwise calculates price
//     function _getPriceV3(
//         address token,
//         uint256 ethPrice,
//         uint32 secondsAgo
//     ) internal view returns (uint256 price, uint256 totalBalance) {
//         uint256 pegPrice = pegTokenPrice(token, ethPrice);

//         if (pegPrice != 0) return (pegPrice, 1);

//         uint256 tempPrice;
//         uint256 totalPrice;

//         uint24[] memory fees = new uint24[](4);
//         fees[0] = 100;
//         fees[1] = 500;
//         fees[2] = 3000;
//         fees[3] = 10000;
//         for (uint24 feeIndex = 0; feeIndex < 4; feeIndex++) {
//             uint24 fee = fees[feeIndex];
//             tempPrice = pairTokensAndValue(token, WETH, fee, secondsAgo);
//             if (tempPrice > 0) {
//                 address pair = pairFor(token, WETH, fee);
//                 uint256 balance = IERC20(token).balanceOf(pair);
//                 totalPrice += ((tempPrice * ethPrice) / 1e18) * balance;
//                 totalBalance += balance;
//             }

//             tempPrice = pairTokensAndValue(token, DAI, fee, secondsAgo);
//             if (tempPrice > 0) {
//                 address pair = pairFor(token, DAI, fee);
//                 uint256 balance = IERC20(token).balanceOf(pair);
//                 totalPrice += tempPrice * balance;
//                 totalBalance += balance;
//             }

//             tempPrice = pairTokensAndValue(token, USDC, fee, secondsAgo);
//             if (tempPrice > 0) {
//                 address pair = pairFor(token, USDC, fee);
//                 uint256 balance = IERC20(token).balanceOf(pair);
//                 totalPrice += tempPrice * balance;
//                 totalBalance += balance;
//             }

//             tempPrice = pairTokensAndValue(token, USDT, fee, secondsAgo);
//             if (tempPrice > 0) {
//                 address pair = pairFor(token, USDT, fee);
//                 uint256 balance = IERC20(token).balanceOf(pair);
//                 totalPrice += tempPrice * balance;
//                 totalBalance += balance;
//             }
//         }

//         if (totalBalance == 0) {
//             return (0, totalBalance);
//         }
//         price = totalPrice / totalBalance;
//     }

//     //if one of the peg tokens, returns that price, otherwise zero
//     function pegTokenPrice(address token, uint256 ethPrice) private pure returns (uint256) {
//         if (token == USDT || token == USDC || token == DAI) return PRECISION;

//         if (token == WETH) return ethPrice;

//         return 0;
//     }

//     //if one of the peg tokens, returns that price, otherwise zero
//     function pegTokenPriceV2(address token, uint256 ethPrice) private pure returns (uint256) {
//         if (token == USDC) return (PRECISION * 1e18) / USDC_RAW_PRICE;
//         if (token == USDT) return (PRECISION * 1e18) / USDT_RAW_PRICE;
//         if (token == DAI) return PRECISION;

//         if (token == WETH) return ethPrice;

//         return 0;
//     }

//     function pegTokenPriceV2(address token) private view returns (uint256) {
//         if (token == USDC) return (PRECISION * 1e18) / USDC_RAW_PRICE;
//         if (token == USDT) return (PRECISION * 1e18) / USDT_RAW_PRICE;
//         if (token == DAI) return PRECISION;

//         if (token == WETH) {
//             (uint256 price, ) = getETHPriceV2();
//             return price;
//         }

//         return 0;
//     }

//     // V2
//     //returns the number of tokens and the USD value within a single LP. peg is one of the listed primary, pegPrice is the predetermined USD value of this token
//     function pairTokensAndValue(address token, address peg) private view returns (uint256 tokenNum, uint256 pegValue) {
//         address tokenPegPair = pairFor(token, peg);

//         // if the address has no contract deployed, the pair doesn't exist
//         uint256 size;

//         assembly {
//             size := extcodesize(tokenPegPair)
//         }

//         if (size == 0) return (0, 0);

//         try IApePair(tokenPegPair).getReserves() returns (uint112 reserve0, uint112 reserve1, uint32) {
//             uint256 reservePeg;

//             (tokenNum, reservePeg) = token < peg ? (reserve0, reserve1) : (reserve1, reserve0);

//             pegValue = reservePeg * pegTokenPriceV2(peg);
//         } catch {
//             return (0, 0);
//         }
//     }

//     // V3
//     //returns the number of tokens and the USD value within a single LP. peg is one of the listed primary, pegPrice is the predetermined USD value of this token
//     function pairTokensAndValue(
//         address token0,
//         address token1,
//         uint24 fee,
//         uint32 secondsAgo
//     ) public view returns (uint256 price) {
//         address tokenPegPair = pairFor(token0, token1, fee);

//         // if the address has no contract deployed, the pair doesn't exist
//         uint256 size;

//         assembly {
//             size := extcodesize(tokenPegPair)
//         }

//         if (size == 0) return 0;

//         uint256 sqrtPriceX96;

//         if (secondsAgo == 0) {
//             // return the current price if secondsAgo == 0
//             (sqrtPriceX96, , , , , , ) = IUniswapV3Pool(tokenPegPair).slot0();
//         } else {
//             uint32[] memory secondsAgos = new uint32[](2);
//             secondsAgos[0] = secondsAgo; // from (before)
//             secondsAgos[1] = 0; // to (now)

//             (int56[] memory tickCumulatives, ) = IUniswapV3Pool(tokenPegPair).observe(secondsAgos);

//             // tick(imprecise as it's an integer) to price
//             sqrtPriceX96 = TickMath.getSqrtRatioAtTick(int24((tickCumulatives[1] - tickCumulatives[0]) / secondsAgo));
//         }

//         uint256 token0Decimals;
//         try ERC20(token0).decimals() returns (uint8 dec) {
//             token0Decimals = dec;
//         } catch {
//             token0Decimals = 18;
//         }

//         uint256 token1Decimals;
//         try ERC20(token1).decimals() returns (uint8 dec) {
//             token1Decimals = dec;
//         } catch {
//             token1Decimals = 18;
//         }

//         //Makes sure it doesn't overflow
//         uint256 decimalCorrection = 0;
//         if (sqrtPriceX96 >= 340282366920938463463374607431768211455) {
//             sqrtPriceX96 = sqrtPriceX96 / 1e3;
//             decimalCorrection = 6;
//         }

//         if (token1 < token0) {
//             price =
//                 (2**192) /
//                 ((sqrtPriceX96)**2 / uint256(10**(token0Decimals + 18 - token1Decimals - decimalCorrection)));
//         } else {
//             price =
//                 ((sqrtPriceX96)**2) /
//                 ((2**192) / uint256(10**(token0Decimals + 18 - token1Decimals - decimalCorrection)));
//         }
//     }

//     //normalize a token price to a specified number of decimals
//     function normalize(
//         uint256 price,
//         address token,
//         uint256 _decimals
//     ) private view returns (uint256) {
//         uint256 tokenDecimals;

//         try ERC20(token).decimals() returns (uint8 dec) {
//             tokenDecimals = dec;
//         } catch {
//             tokenDecimals = 18;
//         }

//         if (tokenDecimals + _decimals <= 2 * DECIMALS) return price / 10**(2 * DECIMALS - tokenDecimals - _decimals);
//         else return price * 10**(_decimals + tokenDecimals - 2 * DECIMALS);
//     }

//     //PairFor V2
//     function pairFor(address tokenA, address tokenB) private pure returns (address pair) {
//         (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

//         pair = address(
//             uint160(
//                 uint256(
//                     keccak256(
//                         abi.encodePacked(
//                             hex"ff",
//                             FACTORYV2,
//                             keccak256(abi.encodePacked(token0, token1)),
//                             INITCODEHASHV2
//                         )
//                     )
//                 )
//             )
//         );
//     }

//     //PairFor V3
//     struct PoolKey {
//         address token0;
//         address token1;
//         uint24 fee;
//     }

//     function getPoolKey(
//         address tokenA,
//         address tokenB,
//         uint24 fee
//     ) internal pure returns (PoolKey memory) {
//         if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);
//         return PoolKey({token0: tokenA, token1: tokenB, fee: fee});
//     }

//     function pairFor(
//         address tokenA,
//         address tokenB,
//         uint24 fee
//     ) internal pure returns (address pool) {
//         if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);
//         PoolKey memory key = PoolKey({token0: tokenA, token1: tokenB, fee: fee});

//         pool = address(
//             uint160(
//                 uint256(
//                     keccak256(
//                         abi.encodePacked(
//                             hex"ff",
//                             FACTORYV3,
//                             keccak256(abi.encode(key.token0, key.token1, key.fee)),
//                             INITCODEHASHV3
//                         )
//                     )
//                 )
//             )
//         );
//     }
// }
