// // SPDX-License-Identifier: GPL-3.0-only
// pragma solidity 0.8.16;

// import "./IPriceGetterV2.sol";
// import "../token-lib/IERC20.sol";
// import "../interfaces/IApePair.sol";
// import "../interfaces/IApeFactory.sol";
// import "../chainlink/ChainlinkOracle.sol";
// import "../interfaces/ISolidlyFactory.sol";
// import "../interfaces/IUniswapV3PoolStateSlot0.sol";
// import "../interfaces/IAlgebraPool.sol";
// import "../interfaces/IXfaiFactory.sol";
// import "../interfaces/IXfaiPool.sol";
// import "../lib/UtilityLibrary.sol";

// import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
// import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
// import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// /**
// VERSION: 2.3

// DISCLAIMER: 
// This smart contract is provided for user interface purposes only and is not intended to be used for smart contract logic. 
// Any attempt to rely on this code for the execution of a smart contract may result in unexpected behavior, 
// errors, or other issues that could lead to financial loss or other damages. 
// The user assumes all responsibility and risk for proper usage. 
// The developer and associated parties make no warranties and are not liable for any damages incurred.
// */

// contract PriceGetterV2 is IPriceGetterV2, ChainlinkOracle, Initializable, OwnableUpgradeable {
//     enum OracleType {
//         NONE,
//         CHAIN_LINK
//     }

//     struct OracleInfo {
//         OracleType oracleType;
//         address oracleAddress;
//         uint8 oracleDecimals;
//     }

//     struct LocalVarsV2Price {
//         uint256 usdStableTotal;
//         uint256 wNativeReserve;
//         uint256 wNativeTotal;
//         uint256 tokenReserve;
//         uint256 stableUsdReserve;
//     }

//     mapping(address => OracleInfo) public tokenOracles;
//     address public wNative;
//     uint8 wNativeDecimals;
//     address[] public stableUsdTokens;
//     mapping(address => uint8) public stableUsdTokenDecimals;
//     IApeFactory public defaultFactoryV2;
//     IUniswapV3Factory public defaultFactoryV3;
//     IAlgebraFactory public defaultFactoryAlgebra;
//     ISolidlyFactory public defaultFactorySolidly;
//     IXfaiFactory public defaultFactoryXFAI;
//     uint24 public secondsAgo;
//     uint256 public nativeLiquidityThreshold;

//     /**
//      * @dev This contract constructor takes in several parameters which includes the wrapped native token address,
//      * an array of addresses for stable USD tokens, an array of addresses for oracle tokens, and an array of addresses
//      * for oracles.
//      *
//      * @param _wNative Address of the wrapped native token
//      * @param _defaultFactoryV2 Address of factoryV2
//      * @param _defaultFactoryV3 Address of factoryV3
//      * @param _stableUsdTokens Array of stable USD token addresses
//      * @param _oracleTokens Array of oracle token addresses
//      * @param _oracles Array of oracle addresses
//      */
//     function initialize(
//         address _wNative,
//         uint256 _nativeLiquidityThreshold,
//         IApeFactory _defaultFactoryV2,
//         IUniswapV3Factory _defaultFactoryV3,
//         IAlgebraFactory _defaultFactoryAlgebra,
//         ISolidlyFactory _defaultFactorySolidly,
//         IXfaiFactory _defaultFactoryXFAI,
//         address[] memory _stableUsdTokens,
//         address[] memory _oracleTokens,
//         address[] memory _oracles
//     ) public initializer {
//         __Ownable_init();
//         secondsAgo = 0;
//         nativeLiquidityThreshold = _nativeLiquidityThreshold;
//         // Check if the lengths of the oracleTokens and oracles arrays match
//         require(_oracleTokens.length == _oracles.length, "Oracle length mismatch");

//         // Loop through the oracleTokens array and set the oracle address for each oracle token using the _setTokenOracle() internal helper function
//         for (uint256 i = 0; i < _oracleTokens.length; i++) {
//             /// @dev Assumes OracleType.CHAIN_LINK
//             _setTokenOracle(_oracleTokens[i], _oracles[i], OracleType.CHAIN_LINK);
//         }

//         // Add the stable USD tokens to the stableCoins array using the addStableUsdTokens() internal helper function
//         addStableUsdTokens(_stableUsdTokens);

//         // Set the wrapped native token (wNative) address
//         wNative = _wNative;
//         wNativeDecimals = UtilityLibrary._getTokenDecimals(wNative);

//         // Set the factory addresses
//         defaultFactoryV2 = _defaultFactoryV2;
//         defaultFactoryV3 = _defaultFactoryV3;
//         defaultFactoryAlgebra = _defaultFactoryAlgebra;
//         defaultFactorySolidly = _defaultFactorySolidly;
//         defaultFactoryXFAI = _defaultFactoryXFAI;
//     }

//     /** SETTERS */

//     function setDefaultFactory(Protocol _protocol, address _factory) public onlyOwner {
//         if (_protocol == Protocol.V2) {
//             defaultFactoryV2 = IApeFactory(_factory);
//         } else if (_protocol == Protocol.V3) {
//             defaultFactoryV3 = IUniswapV3Factory(_factory);
//         } else if (_protocol == Protocol.Algebra) {
//             defaultFactoryAlgebra = IAlgebraFactory(_factory);
//         } else if (_protocol == Protocol.Solidly) {
//             defaultFactorySolidly = ISolidlyFactory(_factory);
//         } else if (_protocol == Protocol.XFAI) {
//             defaultFactoryXFAI = IXfaiFactory(_factory);
//         }
//     }

//     /**
//      * @dev Adds new stable USD tokens to the list of supported stable USD tokens.
//      * @param newStableUsdTokens An array of addresses representing the new stable USD tokens to add.
//      */
//     function addStableUsdTokens(address[] memory newStableUsdTokens) public onlyOwner {
//         for (uint256 i = 0; i < newStableUsdTokens.length; i++) {
//             address stableUsdToken = newStableUsdTokens[i];
//             stableUsdTokens.push(newStableUsdTokens[i]);
//             require(stableUsdTokenDecimals[stableUsdToken] == 0, "PriceGetter: token already added");
//             stableUsdTokenDecimals[stableUsdToken] = UtilityLibrary._getTokenDecimals(stableUsdToken);
//         }
//     }

//     /**
//      * @dev Sets the oracle address and type for a specified token.
//      * @param token The address of the token to set the oracle for.
//      * @param oracleAddress The address of the oracle contract.
//      * @param oracleType The type of the oracle (e.g. Chainlink, Uniswap).
//      */
//     function setTokenOracle(address token, address oracleAddress, OracleType oracleType) public onlyOwner {
//         _setTokenOracle(token, oracleAddress, oracleType);
//     }

//     function setNativeLiquidityThreshold(uint256 _nativeLiquidityThreshold) public onlyOwner {
//         nativeLiquidityThreshold = _nativeLiquidityThreshold;
//     }

//     /**
//      * @dev Removes the oracle address for a specified token.
//      * @param token The address of the token to set the oracle for.
//      */
//     function removeTokenOracle(address token) public onlyOwner {
//         delete tokenOracles[token];
//     }

//     /**
//      * @dev Sets the oracle address and type for a specified token.
//      * @param token The address of the token to set the oracle for.
//      * @param oracleAddress The address of the oracle contract.
//      * @param oracleType The type of the oracle (e.g. Chainlink, Uniswap).
//      */
//     function _setTokenOracle(address token, address oracleAddress, OracleType oracleType) internal {
//         uint8 oracleDecimals = 18;
//         try IERC20(oracleAddress).decimals() returns (uint8 dec) {
//             oracleDecimals = dec;
//         } catch {}

//         tokenOracles[token] = OracleInfo({
//             oracleType: oracleType,
//             oracleAddress: oracleAddress,
//             oracleDecimals: oracleDecimals
//         });
//     }

//     /** GETTERS */

//     // ===== Get LP Prices =====

//     /**
//      * @dev Returns the price of a liquidity pool
//      * @param lp The address of the LP token contract.
//      * @return price The current price of the LP token.
//      */
//     function getLPPriceV2(address lp) public view override returns (uint256 price) {
//         return getLPPriceV2FromFactory(defaultFactoryV2, lp);
//     }

//     function getLPPriceV2FromFactory(IApeFactory factoryV2, address lp) public view override returns (uint256 price) {
//         //if not a LP, handle as a standard token
//         try IApePair(lp).getReserves() returns (uint112 reserve0, uint112 reserve1, uint32) {
//             address token0 = IApePair(lp).token0();
//             address token1 = IApePair(lp).token1();
//             uint256 totalSupply = IApePair(lp).totalSupply();

//             //price0*reserve0+price1*reserve1
//             (uint256 token0Price, ) = _getPriceV2(factoryV2, token0);
//             (uint256 token1Price, ) = _getPriceV2(factoryV2, token1);
//             reserve0 = UtilityLibrary._normalizeToken112(reserve0, token0);
//             reserve1 = UtilityLibrary._normalizeToken112(reserve1, token1);
//             uint256 totalValue = (token0Price * uint256(reserve0)) + (token1Price * uint256(reserve1));

//             return totalValue / totalSupply;
//         } catch {
//             /// @dev If the pair is not a valid LP, return the price of the token
//             (uint256 lpPrice, ) = _getPriceV2(factoryV2, lp);
//             return lpPrice;
//         }
//     }

//     /**
//      * @dev Returns the price of a liquidity pool
//      * @param lp The address of the LP token contract.
//      * @return price The current price of the LP token.
//      */
//     function getLPPriceXFAI(address lp) public view override returns (uint256 price) {
//         return getLPPriceXFAIFromFactory(defaultFactoryXFAI, lp);
//     }

//     function getLPPriceXFAIFromFactory(
//         IXfaiFactory factoryXFAI,
//         address lp
//     ) public view override returns (uint256 price) {
//         //if not a LP, handle as a standard token
//         try IApePair(lp).getReserves() returns (uint112 reserve0, uint112 reserve1, uint32) {
//             address token0 = IApePair(lp).token0();
//             address token1 = IApePair(lp).token1();
//             uint256 totalSupply = IApePair(lp).totalSupply();

//             //price0*reserve0+price1*reserve1
//             (uint256 token0Price, ) = _getPriceXFAI(factoryXFAI, token0);
//             (uint256 token1Price, ) = _getPriceXFAI(factoryXFAI, token1);
//             reserve0 = UtilityLibrary._normalizeToken112(reserve0, token0);
//             reserve1 = UtilityLibrary._normalizeToken112(reserve1, token1);
//             uint256 totalValue = (token0Price * uint256(reserve0)) + (token1Price * uint256(reserve1));

//             return totalValue / totalSupply;
//         } catch {
//             /// @dev If the pair is not a valid LP, return the price of the token
//             (uint256 lpPrice, ) = _getPriceXFAI(factoryXFAI, lp);
//             return lpPrice;
//         }
//     }

//     /**
//      * @dev Returns the price of a liquidity pool
//      * @param lp The address of the LP token contract.
//      * @return price The current price of the LP token.
//      */
//     function getLPPriceSolidly(address lp) public view returns (uint256 price) {
//         return getLPPriceSolidlyFromFactory(defaultFactorySolidly, lp);
//     }

//     function getLPPriceSolidlyFromFactory(
//         ISolidlyFactory factorySolidly,
//         address lp
//     ) public view returns (uint256 price) {
//         //if not a LP, handle as a standard token
//         try IApePair(lp).getReserves() returns (uint112 reserve0, uint112 reserve1, uint32) {
//             address token0 = IApePair(lp).token0();
//             address token1 = IApePair(lp).token1();
//             uint256 totalSupply = IApePair(lp).totalSupply();

//             //price0*reserve0+price1*reserve1
//             (uint256 token0Price, ) = _getPriceSolidly(factorySolidly, token0);
//             (uint256 token1Price, ) = _getPriceSolidly(factorySolidly, token1);
//             reserve0 = UtilityLibrary._normalizeToken112(reserve0, token0);
//             reserve1 = UtilityLibrary._normalizeToken112(reserve1, token1);
//             uint256 totalValue = (token0Price * uint256(reserve0)) + (token1Price * uint256(reserve1));

//             return totalValue / totalSupply;
//         } catch {
//             /// @dev If the pair is not a valid LP, return the price of the token
//             (uint256 lpPrice, ) = _getPriceSolidly(factorySolidly, lp);
//             return lpPrice;
//         }
//     }

//     /**
//      * @dev Returns the prices of multiple LP tokens using the getLPPriceV2 function.
//      * @param tokens An array of LP token addresses to get the prices for.
//      * @return prices An array of prices for the specified LP tokens.
//      */
//     function getLPPricesV2(address[] calldata tokens) public view override returns (uint256[] memory prices) {
//         return getLPPricesV2FromFactory(defaultFactoryV2, tokens);
//     }

//     /**
//      * @dev This function takes in an instance of the ApeSwap factory contract and an array of token addresses,
//      * and returns an array of prices for each corresponding liquidity pool. It iterates through each token address,
//      * and calls the `getLPPriceV2` function to retrieve the price of the corresponding liquidity pool. The prices
//      * are stored in an array and returned.
//      *
//      * @param factoryV2 An instance of the ApeSwap factory contract
//      * @param tokens An array of token addresses
//      * @return prices An array of prices for each corresponding liquidity pool
//      */
//     function getLPPricesV2FromFactory(
//         IApeFactory factoryV2,
//         address[] calldata tokens
//     ) public view returns (uint256[] memory prices) {
//         prices = new uint256[](tokens.length);
//         for (uint256 i; i < prices.length; i++) {
//             address token = tokens[i];
//             prices[i] = getLPPriceV2FromFactory(factoryV2, token);
//         }
//     }

//     // /**
//     //  * @dev Returns the prices of multiple LP tokens using the getLPPriceV2 function.
//     //  * @param tokens An array of LP token addresses to get the prices for.
//     //  * @return prices An array of prices for the specified LP tokens.
//     //  */
//     function getLPPricesXFAI(address[] calldata tokens) public view override returns (uint256[] memory prices) {
//         return getLPPricesXFAIFromFactory(defaultFactoryXFAI, tokens);
//     }

//     /**
//      * @dev This function takes in an instance of the ApeSwap factory contract and an array of token addresses,
//      * and returns an array of prices for each corresponding liquidity pool. It iterates through each token address,
//      * and calls the `getLPPriceXFAI` function to retrieve the price of the corresponding liquidity pool. The prices
//      * are stored in an array and returned.
//      *
//      * @param factoryXFAI An instance of the ApeSwap factory contract
//      * @param tokens An array of token addresses
//      * @return prices An array of prices for each corresponding liquidity pool
//      */
//     function getLPPricesXFAIFromFactory(
//         IXfaiFactory factoryXFAI,
//         address[] calldata tokens
//     ) public view returns (uint256[] memory prices) {
//         prices = new uint256[](tokens.length);
//         for (uint256 i; i < prices.length; i++) {
//             address token = tokens[i];
//             prices[i] = getLPPriceXFAIFromFactory(factoryXFAI, token);
//         }
//     }

//     /**
//      * @dev Returns the prices of multiple LP tokens using the getLPPriceV2 function.
//      * @param tokens An array of LP token addresses to get the prices for.
//      * @return prices An array of prices for the specified LP tokens.
//      */
//     function getLPPricesSolidly(address[] calldata tokens) public view returns (uint256[] memory prices) {
//         return getLPPricesSolidlyFromFactory(defaultFactorySolidly, tokens);
//     }

//     /**
//      * @dev This function takes in an instance of the ApeSwap factory contract and an array of token addresses,
//      * and returns an array of prices for each corresponding liquidity pool. It iterates through each token address,
//      * and calls the `getLPPriceV2` function to retrieve the price of the corresponding liquidity pool. The prices
//      * are stored in an array and returned.
//      *
//      * @param factorySolidly An instance of the ApeSwap factory contract
//      * @param tokens An array of token addresses
//      * @return prices An array of prices for each corresponding liquidity pool
//      */
//     function getLPPricesSolidlyFromFactory(
//         ISolidlyFactory factorySolidly,
//         address[] calldata tokens
//     ) public view returns (uint256[] memory prices) {
//         prices = new uint256[](tokens.length);
//         for (uint256 i; i < prices.length; i++) {
//             address token = tokens[i];
//             prices[i] = getLPPriceSolidlyFromFactory(factorySolidly, token);
//         }
//     }

//     /**
//      * @dev Returns the price of an LP token.
//      * @param token0 The address of the first token in the LP pair.
//      * @param token1 The address of the second token in the LP pair.
//      * @param fee The Uniswap V3 pool fee.
//      * @return price The price of the LP token.
//      */
//     function getLPPriceV3(address token0, address token1, uint24 fee) public view override returns (uint256 price) {
//         return getLPPriceV3FromFactory(address(defaultFactoryV3), token0, token1, fee);
//     }

//     /**
//      * @dev Returns the price of an LP token.
//      * @param token0 The address of the first token in the LP pair.
//      * @param token1 The address of the second token in the LP pair.
//      * @return price The price of the LP token.
//      */
//     function getLPPriceAlgebra(address token0, address token1) public view override returns (uint256 price) {
//         return getLPPriceAlgebraFromFactory(defaultFactoryAlgebra, token0, token1);
//     }

//     /**
//      * @dev Returns the price of a gamma LP token.
//      * @param lp The address of the gamma LP pair.
//      * @return price The price of the gamma LP token.
//      */
//     function getLPPriceGamma(Hypervisor lp) public view override returns (uint256 price) {
//         return getLPPriceGammaFromFactory(defaultFactoryAlgebra, defaultFactoryV2, lp);
//     }

//     function getLPPriceGammaFromFactory(
//         IAlgebraFactory factory,
//         IApeFactory factoryV2,
//         Hypervisor lp
//     ) public view override returns (uint256 price) {
//         if (address(factoryV2) == address(0)) {
//             factoryV2 = defaultFactoryV2;
//         }
//         (uint256 priceToken0, ) = _getPriceAlgebra(factory, address(lp.token0()));
//         if (priceToken0 == 0) {
//             (priceToken0, ) = _getPriceV2(factoryV2, address(lp.token0()));
//         }
//         (uint256 priceToken1, ) = _getPriceAlgebra(factory, address(lp.token1()));
//         if (priceToken1 == 0) {
//             (priceToken1, ) = _getPriceV2(factoryV2, address(lp.token0()));
//         }
//         (uint256 total0, uint256 total1) = lp.getTotalAmounts();
//         price =
//             (priceToken0 *
//                 UtilityLibrary._normalizeToken(total0, address(lp.token0())) +
//                 priceToken1 *
//                 UtilityLibrary._normalizeToken(total1, address(lp.token1()))) /
//             lp.totalSupply();
//     }

//     // /**
//     //  * @dev Returns the price of a steer LP token.
//     //  * @param factoryV3 The address of the V3 factory
//     //  * @param factoryV2 The address of the V2 factory
//     //  * @param lp The address of the steer LP pair.
//     //  * @return price The price of the steer LP token.
//     //  */
//     function getLPPriceSteerFromFactory(
//         IUniswapV3Factory factoryV3,
//         IApeFactory factoryV2,
//         ISteerVault lp
//     ) public view override returns (uint256 price) {
//         if (address(factoryV2) == address(0)) {
//             factoryV2 = defaultFactoryV2;
//         }
//         (uint256 priceToken0, ) = _getPriceV3(factoryV3, address(lp.token0()));
//         if (priceToken0 == 0) {
//             (priceToken0, ) = _getPriceV2(factoryV2, address(lp.token0()));
//         }
//         (uint256 priceToken1, ) = _getPriceV3(factoryV3, address(lp.token1()));
//         if (priceToken1 == 0) {
//             (priceToken1, ) = _getPriceV2(factoryV2, address(lp.token0()));
//         }
//         (uint256 total0, uint256 total1) = lp.getTotalAmounts();
//         price =
//             (priceToken0 *
//                 UtilityLibrary._normalizeToken(total0, address(lp.token0())) +
//                 priceToken1 *
//                 UtilityLibrary._normalizeToken(total1, address(lp.token1()))) /
//             lp.totalSupply();
//     }

//     /**
//      * @dev Returns the price of an LP token.
//      * @param token0 The address of the first token in the LP pair.
//      * @param token1 The address of the second token in the LP pair.
//      * @return price The price of the LP token.
//      */
//     function getLPPriceAlgebraFromFactory(
//         IAlgebraFactory factoryAlgebra,
//         address token0,
//         address token1
//     ) public view override returns (uint256 price) {
//         return getLPPriceV3FromFactory(address(factoryAlgebra), token0, token1, 0);
//     }

//     /**
//      * @dev This function takes in an instance of the Uniswap V3 factory contract, token addresses and fee amount,
//      * and returns the price of the corresponding liquidity pool. It first retrieves the address of the liquidity pool
//      * using the `getPool` function of the Uniswap V3 factory contract. If the pair doesn't exist, it returns 0.
//      * Otherwise, it retrieves the current sqrt price of the pool from the slot0 data of the pool. It then calculates
//      * the decimal correction factor to adjust for different decimals between the two tokens. Finally, it calculates
//      * and returns the price of the pool.
//      *
//      * @param factoryV3 An instance of the Uniswap V3 factory contract
//      * @param token0 The address of one token in the liquidity pool
//      * @param token1 The address of the other token in the liquidity pool
//      * @param fee The fee amount of the liquidity pool
//      * @dev If fee set to 0 it gets price from algebra
//      * @return price The price of the liquidity pool
//      */
//     function getLPPriceV3FromFactory(
//         address factoryV3,
//         address token0,
//         address token1,
//         uint24 fee
//     ) public view override returns (uint256 price) {
//         address tokenPegPair;
//         if (fee == 0) {
//             tokenPegPair = IAlgebraFactory(factoryV3).poolByPair(token0, token1);
//         } else {
//             tokenPegPair = IUniswapV3Factory(factoryV3).getPool(token0, token1, fee);
//         }

//         // if the address has no contract deployed, the pair doesn't exist
//         uint256 size;

//         assembly {
//             size := extcodesize(tokenPegPair)
//         }

//         if (size == 0) return 0;

//         uint256 sqrtPriceX96;
//         if (secondsAgo == 0) {
//             // return the current price if secondsAgo == 0
//             if (fee == 0) {
//                 (sqrtPriceX96, , , , , , ) = IAlgebraPool(tokenPegPair).globalState();
//             } else {
//                 (sqrtPriceX96, , , , , , ) = IUniswapV3PoolStateSlot0(tokenPegPair).slot0();
//             }
//         } else {
//             uint32[] memory secondsAgos = new uint32[](2);
//             secondsAgos[0] = secondsAgo; // from (before)
//             secondsAgos[1] = 0; // to (now)

//             (int56[] memory tickCumulatives, ) = IUniswapV3Pool(tokenPegPair).observe(secondsAgos);

//             // tick(imprecise as it's an integer) to price
//             sqrtPriceX96 = TickMath.getSqrtRatioAtTick(
//                 int24((tickCumulatives[1] - tickCumulatives[0]) / int56(int24(secondsAgo)))
//             );
//         }

//         uint256 token0Decimals;
//         try IERC20(token0).decimals() returns (uint8 dec) {
//             token0Decimals = dec;
//         } catch {
//             token0Decimals = 18;
//         }

//         uint256 token1Decimals;
//         try IERC20(token1).decimals() returns (uint8 dec) {
//             token1Decimals = dec;
//         } catch {
//             token1Decimals = 18;
//         }

//         if (sqrtPriceX96 == 0) {
//             return 0;
//         }
//         //Makes sure it doesn't overflow
//         uint256 decimalCorrection = 0;
//         if (sqrtPriceX96 >= 340282366920938463463374607431768211455) {
//             sqrtPriceX96 = sqrtPriceX96 / 1e3;
//             decimalCorrection = 6;
//         }
//         if (sqrtPriceX96 >= 340282366920938463463374607431768211455) {
//             return 0;
//         }

//         if (token1 < token0) {
//             price =
//                 (2 ** 192) /
//                 ((sqrtPriceX96) ** 2 / uint256(10 ** (token0Decimals + 18 - token1Decimals - decimalCorrection)));
//         } else {
//             price =
//                 ((sqrtPriceX96) ** 2) /
//                 ((2 ** 192) / uint256(10 ** (token0Decimals + 18 - token1Decimals - decimalCorrection)));
//         }
//     }

//     /**
//      * @dev Returns the prices of multiple LP tokens using the getLPPriceV3 function.
//      * @param tokens0 An array of addresses representing the first tokens in the LP pairs to get the prices for.
//      * @param tokens1 An array of addresses representing the second tokens in the LP pairs to get the prices for.
//      * @param fees An array of Uniswap V3 pool fees for each LP pair.
//      * @return prices An array of prices for the specified LP tokens.
//      */
//     function getLPPricesV3(
//         address[] calldata tokens0,
//         address[] calldata tokens1,
//         uint24[] calldata fees
//     ) public view override returns (uint256[] memory prices) {
//         return getLPPricesV3FromFactory(defaultFactoryV3, tokens0, tokens1, fees);
//     }

//     /**
//      * @dev This function takes in an instance of the Uniswap V3 factory contract, arrays of token addresses and fees,
//      * and returns an array of prices for each pair of tokens. It loops through each pair of tokens and calls the
//      * `getLPPriceV3` function to get the price of the corresponding liquidity pool. The resulting prices are stored
//      * in an array and returned.
//      *
//      * @param factoryV3 An instance of the Uniswap V3 factory contract
//      * @param tokens0 An array of addresses representing the first tokens in the LP pairs to get the prices for.
//      * @param tokens1 An array of addresses representing the second tokens in the LP pairs to get the prices for.
//      * @param fees An array of Uniswap V3 pool fees for each LP pair.
//      * @return prices An array of prices for the specified LP tokens.
//      */
//     function getLPPricesV3FromFactory(
//         IUniswapV3Factory factoryV3,
//         address[] calldata tokens0,
//         address[] calldata tokens1,
//         uint24[] calldata fees
//     ) public view override returns (uint256[] memory prices) {
//         require(tokens0.length == tokens1.length && tokens0.length == fees.length, "LENGTH_MISMATCH");
//         uint256 tokensLength = tokens0.length;
//         prices = new uint256[](tokensLength);
//         for (uint256 i; i < tokensLength; i++) {
//             address token0 = tokens0[i];
//             address token1 = tokens1[i];
//             uint24 fee = fees[i];
//             prices[i] = getLPPriceV3FromFactory(address(factoryV3), token0, token1, fee);
//         }
//     }

//     function getLPPriceWrappedV3FromFactory(
//         IUniswapV3Factory factory,
//         IApeFactory factoryV2,
//         Hypervisor lp
//     ) public view returns (uint256 price) {
//         if (address(factoryV2) == address(0)) {
//             factoryV2 = defaultFactoryV2;
//         }
//         (uint256 priceToken0, ) = _getPriceV3(factory, address(lp.token0()));
//         if (priceToken0 == 0) {
//             (priceToken0, ) = _getPriceV2(factoryV2, address(lp.token0()));
//         }
//         (uint256 priceToken1, ) = _getPriceV3(factory, address(lp.token1()));
//         if (priceToken1 == 0) {
//             (priceToken1, ) = _getPriceV2(factoryV2, address(lp.token0()));
//         }
//         (uint256 total0, uint256 total1) = lp.getTotalAmounts();
//         price =
//             (priceToken0 *
//                 UtilityLibrary._normalizeToken(total0, address(lp.token0())) +
//                 priceToken1 *
//                 UtilityLibrary._normalizeToken(total1, address(lp.token1()))) /
//             lp.totalSupply();
//     }

//     /**
//      * @dev Returns the prices of LP token from a specic protocol an factory.
//      * @param protocol The protocol version to use
//      * @param factoryV2 The address of the V2 factory
//      * @param factoryV3 The address of the V3 factory
//      * @param factoryAlgebra The address of the Algebra factory
//      * @return price The current price of LP.
//      * @dev Protocol V3 and Algebra not yet supported in here because functions token 2 tokens instead of 1 and for V3 also a fee.
//      * Use the dedicated functions for these protocols
//      */
//     function getLPPriceFromFactory(
//         address token,
//         Protocol protocol,
//         IApeFactory factoryV2,
//         IUniswapV3Factory factoryV3,
//         IAlgebraFactory factoryAlgebra,
//         ISolidlyFactory factorySolidly
//     ) public view override returns (uint256 price) {
//         if (protocol == Protocol.Both) {
//             revert("LP can't be both");
//         } else if (protocol == Protocol.V2) {
//             uint256 lpV2Price = getLPPriceV2FromFactory(factoryV2, token);
//             return lpV2Price;
//         } else if (protocol == Protocol.V3) {
//             uint256 lpV3Price = getLPPriceWrappedV3FromFactory(factoryV3, factoryV2, Hypervisor(token));
//             return lpV3Price;
//         } else if (protocol == Protocol.Algebra) {
//             revert("No support");
//         } else if (protocol == Protocol.Gamma) {
//             uint256 lpAlgebraPrice = getLPPriceGammaFromFactory(factoryAlgebra, factoryV2, Hypervisor(token));
//             return lpAlgebraPrice;
//         } else if (protocol == Protocol.Steer) {
//             revert("No support");
//             // uint256 lpSteerPrice = getLPPriceSteerFromFactory(factoryV3, factoryV2, ISteerVault(token));
//             // return lpSteerPrice;
//         } else if (protocol == Protocol.Solidly) {
//             uint256 lpSolidlyPrice = getLPPriceSolidlyFromFactory(factorySolidly, token);
//             return lpSolidlyPrice;
//         } else {
//             revert("Invalid");
//         }
//     }

//     // ===== Get Native Prices =====

//     /**
//      * @dev Returns the current price of wNative in USD based on the given protocol and time delta.
//      * @param protocol The protocol version to use
//      * @return nativePrice The current price of wNative in USD.
//      */
//     function getNativePrice(Protocol protocol) public view override returns (uint256 nativePrice) {
//         return getNativePriceFromFactory(protocol, defaultFactoryV2, defaultFactoryV3, defaultFactorySolidly);
//     }

//     function getNativePriceFromFactory(
//         Protocol protocol,
//         IApeFactory factoryV2,
//         IUniswapV3Factory factoryV3,
//         ISolidlyFactory factorySolidly
//     ) public view override returns (uint256 nativePrice) {
//         /// @dev Short circuit if oracle price is found
//         uint256 oraclePrice = _getOraclePriceNormalized(wNative);
//         if (oraclePrice > 0) {
//             return oraclePrice;
//         }

//         if (protocol == Protocol.Both) {
//             (uint256 nativeV3Price, uint256 totalNativeV3) = _getNativePriceV3(factoryV3);
//             (uint256 nativeV2Price, uint256 totalNativeV2) = _getNativePriceV2(factoryV2);
//             if (totalNativeV3 + totalNativeV2 == 0) return 0;
//             return (nativeV3Price * totalNativeV3 + nativeV2Price * totalNativeV2) / (totalNativeV3 + totalNativeV2);
//         } else if (protocol == Protocol.V2) {
//             (uint256 nativeV2Price, ) = _getNativePriceV2(factoryV2);
//             return nativeV2Price;
//         } else if (protocol == Protocol.V3) {
//             (uint256 nativeV3Price, ) = _getNativePriceV3(factoryV3);
//             return nativeV3Price;
//         } else if (protocol == Protocol.Algebra) {
//             (uint256 nativeAlgebraPrice, ) = _getNativePriceAlgebra(defaultFactoryAlgebra);
//             return nativeAlgebraPrice;
//         } else if (protocol == Protocol.Solidly) {
//             (uint256 nativeAlgebraPrice, ) = _getNativePriceSolidly(factorySolidly);
//             return nativeAlgebraPrice;
//         } else {
//             revert("Invalid");
//         }
//     }

//     /**
//      * @dev Calculates the price of wNative using V2 pricing.
//      * Compares multiple stable pools and weights by their oracle price.
//      * @param factoryV2 The address of the V2 factory
//      * @return price price of wNative in USD
//      * @return wNativeTotal The total amount of wNative in the pools.
//      */
//     function _getNativePriceV2(IApeFactory factoryV2) internal view returns (uint256 price, uint256 wNativeTotal) {
//         /// @dev This method calculates the price of wNative by comparing multiple stable pools and weighting by their oracle price
//         uint256 usdStableTotal = 0;
//         for (uint256 i = 0; i < stableUsdTokens.length; i++) {
//             address stableUsdToken = stableUsdTokens[i];
//             (uint256 wNativeReserve, uint256 stableUsdReserve) = _getNormalizedReservesFromFactoryV2_Decimals(
//                 factoryV2,
//                 wNative,
//                 stableUsdToken,
//                 wNativeDecimals,
//                 stableUsdTokenDecimals[stableUsdToken]
//             );
//             uint256 stableUsdPrice = _getOraclePriceNormalized(stableUsdToken);
//             if (stableUsdPrice > 0) {
//                 /// @dev Weighting the USD side of the pair by the price of the USD stable token if it exists.
//                 usdStableTotal += (stableUsdReserve * stableUsdPrice) / 1e18;
//             } else {
//                 usdStableTotal += stableUsdReserve;
//             }
//             wNativeTotal += wNativeReserve;
//         }

//         price = (usdStableTotal * 1e18) / wNativeTotal;
//     }

//     /**
//      * @dev Calculates the price of wNative using V2 pricing.
//      * Compares multiple stable pools and weights by their oracle price.
//      * @param factorySolidly The address of the V2 factory
//      * @return price price of wNative in USD
//      * @return wNativeTotal The total amount of wNative in the pools.
//      */
//     function _getNativePriceSolidly(
//         ISolidlyFactory factorySolidly
//     ) internal view returns (uint256 price, uint256 wNativeTotal) {
//         /// @dev This method calculates the price of wNative by comparing multiple stable pools and weighting by their oracle price
//         uint256 usdStableTotal = 0;
//         for (uint256 i = 0; i < stableUsdTokens.length; i++) {
//             address stableUsdToken = stableUsdTokens[i];
//             (uint256 wNativeReserve, uint256 stableUsdReserve) = _getNormalizedReservesFromFactorySolidly_Decimals(
//                 factorySolidly,
//                 wNative,
//                 stableUsdToken,
//                 wNativeDecimals,
//                 stableUsdTokenDecimals[stableUsdToken]
//             );
//             uint256 stableUsdPrice = _getOraclePriceNormalized(stableUsdToken);
//             if (stableUsdPrice > 0) {
//                 /// @dev Weighting the USD side of the pair by the price of the USD stable token if it exists.
//                 usdStableTotal += (stableUsdReserve * stableUsdPrice) / 1e18;
//             } else {
//                 usdStableTotal += stableUsdReserve;
//             }
//             wNativeTotal += wNativeReserve;
//         }

//         price = (usdStableTotal * 1e18) / wNativeTotal;
//     }

//     /**
//      * @dev Calculates the price of wNative using XFAI pricing.
//      * Compares multiple stable pools and weights by their oracle price.
//      * @param factoryXFAI The address of the XFAI factory
//      * @return price price of wNative in USD
//      * @return wNativeTotal The total amount of wNative in the pools.
//      */
//     function _getNativePriceXFAI(IXfaiFactory factoryXFAI) internal view returns (uint256 price, uint256 wNativeTotal) {
//         /// @dev This method calculates the price of wNative by comparing multiple stable pools and weighting by their oracle price
//         uint256 usdStableTotal = 0;
//         for (uint256 i = 0; i < stableUsdTokens.length; i++) {
//             address stableUsdToken = stableUsdTokens[i];
//             (uint256 stableUsdReserve, uint256 wNativeReserve) = _getNormalizedReservesFromFactoryXFAI_Decimals(
//                 factoryXFAI,
//                 stableUsdToken,
//                 stableUsdTokenDecimals[stableUsdToken],
//                 wNativeDecimals
//             );
//             uint256 stableUsdPrice = _getOraclePriceNormalized(stableUsdToken);
//             if (stableUsdPrice > 0) {
//                 /// @dev Weighting the USD side of the pair by the price of the USD stable token if it exists.
//                 usdStableTotal += (stableUsdReserve * stableUsdPrice) / 1e18;
//             } else {
//                 usdStableTotal += stableUsdReserve;
//             }
//             wNativeTotal += wNativeReserve;
//         }

//         price = (usdStableTotal * 1e18) / wNativeTotal;
//     }

//     /**
//      * @dev Calculates the price of wNative using V3 pricing.
//      * Uses Uniswap V3 pools with various fees and stable tokens.
//      * @param factoryV3 The address of the V3 factory
//      * @return price The price of wNative in USD
//      * @return wNativeTotal The total amount of wNative in the pools.
//      */
//     function _getNativePriceV3(
//         IUniswapV3Factory factoryV3
//     ) internal view returns (uint256 price, uint256 wNativeTotal) {
//         uint256 totalPrice;

//         uint24[] memory fees = new uint24[](5);
//         fees[0] = 100;
//         fees[1] = 500;
//         fees[2] = 2500;
//         fees[3] = 3000;
//         fees[4] = 10000;
//         // Loop through each feeIndex
//         for (uint24 feeIndex = 0; feeIndex < 5; feeIndex++) {
//             uint24 fee = fees[feeIndex];
//             // Loop through each stable usd token
//             for (uint256 i = 0; i < stableUsdTokens.length; i++) {
//                 address stableUsdToken = stableUsdTokens[i];
//                 price = getLPPriceV3FromFactory(address(factoryV3), wNative, stableUsdToken, fee);
//                 uint256 stableUsdPrice = _getOraclePriceNormalized(stableUsdToken);
//                 if (stableUsdPrice > 0) {
//                     price = (price * stableUsdPrice) / 1e18;
//                 }
//                 if (price > 0) {
//                     address pair = factoryV3.getPool(wNative, stableUsdToken, fee);
//                     uint256 balance = IERC20(wNative).balanceOf(pair);
//                     totalPrice += price * balance;
//                     wNativeTotal += balance;
//                 }
//             }
//         }

//         if (wNativeTotal == 0) {
//             return (0, wNativeTotal);
//         }
//         price = totalPrice / wNativeTotal;
//     }

//     /**
//      * @dev Calculates the price of wNative using V3 pricing.
//      * Uses Uniswap V3 pools with various fees and stable tokens.
//      * @param factoryAlgebra The address of the V3 factory
//      * @return price The price of wNative in USD
//      * @return wNativeTotal The total amount of wNative in the pools.
//      */
//     function _getNativePriceAlgebra(
//         IAlgebraFactory factoryAlgebra
//     ) internal view returns (uint256 price, uint256 wNativeTotal) {
//         uint256 totalPrice;

//         // Loop through each stable usd token
//         for (uint256 i = 0; i < stableUsdTokens.length; i++) {
//             address stableUsdToken = stableUsdTokens[i];
//             price = getLPPriceV3FromFactory(address(factoryAlgebra), wNative, stableUsdToken, 0);
//             uint256 stableUsdPrice = _getOraclePriceNormalized(stableUsdToken);
//             if (stableUsdPrice > 0) {
//                 price = (price * stableUsdPrice) / 1e18;
//             }
//             if (price > 0) {
//                 address pair = factoryAlgebra.poolByPair(wNative, stableUsdToken);
//                 uint256 balance = IERC20(wNative).balanceOf(pair);
//                 totalPrice += price * balance;
//                 wNativeTotal += balance;
//             }
//         }

//         if (wNativeTotal == 0) {
//             return (0, wNativeTotal);
//         }
//         price = totalPrice / wNativeTotal;
//     }

//     // ===== Get Token Prices =====

//     /**
//      * @dev Returns the current price of the given token based on the specified protocol and time interval.
//      * If protocol is set to 'Both', the price is calculated as a weighted average of the V2 and V3 prices,
//      * where the weights are the respective liquidity pools. If protocol is set to 'V2' or 'V3', the price
//      * is calculated based on the respective liquidity pool.
//      * @param token Address of the token for which the price is requested.
//      * @param protocol The liquidity protocol used to calculate the price.
//      * @return price The price of the token in USD.
//      */
//     function getPrice(address token, Protocol protocol) public view override returns (uint256 price) {
//         return
//             getPriceFromFactory(
//                 token,
//                 protocol,
//                 defaultFactoryV2,
//                 defaultFactoryV3,
//                 defaultFactoryAlgebra,
//                 defaultFactorySolidly,
//                 defaultFactoryXFAI
//             );
//     }

//     function getPriceFromFactory(
//         address token,
//         Protocol protocol,
//         IApeFactory factoryV2,
//         IUniswapV3Factory factoryV3,
//         IAlgebraFactory factoryAlgebra,
//         ISolidlyFactory factorySolidly,
//         IXfaiFactory factoryXFAI
//     ) public view override returns (uint256 price) {
//         if (token == wNative) {
//             return getNativePriceFromFactory(protocol, factoryV2, factoryV3, defaultFactorySolidly);
//         }

//         if (protocol == Protocol.Both) {
//             (uint256 tokenV3Price, uint256 totalTokenV3) = _getPriceV3(factoryV3, token);
//             (uint256 tokenV2Price, uint256 totalTokenV2) = _getPriceV2(factoryV2, token);
//             if (totalTokenV3 + totalTokenV2 == 0) {
//                 return 0;
//             }
//             return (tokenV3Price * totalTokenV3 + tokenV2Price * totalTokenV2) / (totalTokenV3 + totalTokenV2);
//         } else if (protocol == Protocol.V2) {
//             (uint256 tokenV2Price, ) = _getPriceV2(factoryV2, token);
//             return tokenV2Price;
//         } else if (protocol == Protocol.V3) {
//             (uint256 tokenV3Price, ) = _getPriceV3(factoryV3, token);
//             return tokenV3Price;
//         } else if (protocol == Protocol.Algebra) {
//             (uint256 tokenAlgebraPrice, ) = _getPriceAlgebra(factoryAlgebra, token);
//             return tokenAlgebraPrice;
//         } else if (protocol == Protocol.Solidly) {
//             (uint256 tokenAlgebraPrice, ) = _getPriceSolidly(factorySolidly, token);
//             return tokenAlgebraPrice;
//         } else if (protocol == Protocol.XFAI) {
//             // (uint256 tokenAlgebraPrice, ) = _getPriceXFAI(factoryXFAI, token);
//             // return tokenAlgebraPrice;
//             return 0;
//         } else {
//             revert("Invalid");
//         }
//     }

//     /**
//      * @dev Returns an array of prices for the given array of tokens based on the specified protocol and time interval.
//      * @param tokens An array of token addresses for which prices are requested.
//      * @param protocol The liquidity protocol used to calculate the prices.
//      * @return prices An array of prices for the given tokens in USD.
//      */
//     function getPrices(
//         address[] calldata tokens,
//         Protocol protocol
//     ) public view override returns (uint256[] memory prices) {
//         prices = getPricesFromFactory(
//             tokens,
//             protocol,
//             defaultFactoryV2,
//             defaultFactoryV3,
//             defaultFactoryAlgebra,
//             defaultFactorySolidly,
//             defaultFactoryXFAI
//         );
//     }

//     function getPricesFromFactory(
//         address[] calldata tokens,
//         Protocol protocol,
//         IApeFactory factoryV2,
//         IUniswapV3Factory factoryV3,
//         IAlgebraFactory factoryAlgebra,
//         ISolidlyFactory factorySolidly,
//         IXfaiFactory factoryXFAI
//     ) public view override returns (uint256[] memory prices) {
//         uint256 tokenLength = tokens.length;
//         prices = new uint256[](tokenLength);

//         for (uint256 i; i < tokenLength; i++) {
//             address token = tokens[i];
//             prices[i] = getPriceFromFactory(
//                 token,
//                 protocol,
//                 factoryV2,
//                 factoryV3,
//                 factoryAlgebra,
//                 factorySolidly,
//                 factoryXFAI
//             );
//         }
//     }

//     function getPriceV2(address token) public view override returns (uint256 price) {
//         (price, ) = _getPriceV2(defaultFactoryV2, token);
//     }

//     function getPriceV2FromFactory(IApeFactory factoryV2, address token) public view override returns (uint256 price) {
//         (price, ) = _getPriceV2(factoryV2, token);
//     }

//     /**
//      * @dev Returns the price and total balance of the given token based on the XFAI liquidity pool.
//      * @param token Address of the token for which the price and total balance are requested.
//      * @return price The price of the token based on the XFAI liquidity pool.
//      * @return tokenTotal Total balance of the token based on the XFAI liquidity pool.
//      */
//     function _getPriceXFAI(
//         IXfaiFactory factoryXFAI,
//         address token
//     ) internal view returns (uint256 price, uint256 tokenTotal) {
//         (uint256 nativePrice, ) = _getNativePriceXFAI(factoryXFAI);
//         if (token == wNative) {
//             /// @dev Returning high total balance for wNative to heavily weight value.
//             return (nativePrice, 1e36);
//         }

//         LocalVarsV2Price memory vars;

//         (vars.tokenReserve, vars.wNativeReserve) = _getNormalizedReservesFromFactoryXFAI_Decimals(
//             factoryXFAI,
//             token,
//             UtilityLibrary._getTokenDecimals(token),
//             wNativeDecimals
//         );
//         vars.wNativeTotal = (vars.wNativeReserve * nativePrice) / 1e18;
//         tokenTotal += vars.tokenReserve;

//         price = (vars.wNativeTotal * 1e18) / tokenTotal;
//     }

//     function getPriceXFAI(address token) public view override returns (uint256 price) {
//         (price, ) = _getPriceXFAI(defaultFactoryXFAI, token);
//     }

//     function getPriceXFAIFromFactory(
//         IXfaiFactory factoryXFAI,
//         address token
//     ) public view override returns (uint256 price) {
//         (price, ) = _getPriceXFAI(factoryXFAI, token);
//     }

//     /**
//      * @dev Returns the price and total balance of the given token based on the V2 liquidity pool.
//      * @param token Address of the token for which the price and total balance are requested.
//      * @return price The price of the token based on the V2 liquidity pool.
//      * @return tokenTotal Total balance of the token based on the V2 liquidity pool.
//      */
//     function _getPriceV2(
//         IApeFactory factoryV2,
//         address token
//     ) internal view returns (uint256 price, uint256 tokenTotal) {
//         uint256 nativePrice = getNativePriceFromFactory(
//             Protocol.V2,
//             defaultFactoryV2,
//             IUniswapV3Factory(address(0)),
//             defaultFactorySolidly
//         );
//         if (token == wNative) {
//             /// @dev Returning high total balance for wNative to heavily weight value.
//             return (nativePrice, 1e36);
//         }

//         LocalVarsV2Price memory vars;

//         (vars.tokenReserve, vars.wNativeReserve) = _getNormalizedReservesFromFactoryV2_Decimals(
//             factoryV2,
//             token,
//             wNative,
//             UtilityLibrary._getTokenDecimals(token),
//             wNativeDecimals
//         );
//         vars.wNativeTotal = (vars.wNativeReserve * nativePrice) / 1e18;
//         tokenTotal += vars.tokenReserve;

//         for (uint256 i = 0; i < stableUsdTokens.length; i++) {
//             address stableUsdToken = stableUsdTokens[i];
//             (vars.tokenReserve, vars.stableUsdReserve) = _getNormalizedReservesFromFactoryV2_Decimals(
//                 factoryV2,
//                 token,
//                 stableUsdToken,
//                 UtilityLibrary._getTokenDecimals(token),
//                 stableUsdTokenDecimals[stableUsdToken]
//             );
//             uint256 stableUsdPrice = _getOraclePriceNormalized(stableUsdToken);

//             if (vars.stableUsdReserve > 10e18) {
//                 if (stableUsdPrice > 0) {
//                     /// @dev Weighting the USD side of the pair by the price of the USD stable token if it exists.
//                     vars.usdStableTotal += (vars.stableUsdReserve * stableUsdPrice) / 1e18;
//                 } else {
//                     vars.usdStableTotal += vars.stableUsdReserve;
//                 }
//                 tokenTotal += vars.tokenReserve;
//             }
//         }

//         if (tokenTotal == 0) {
//             return (0, 0);
//         }
//         price = ((vars.usdStableTotal + vars.wNativeTotal) * 1e18) / tokenTotal;
//     }

//     /**
//      * @dev Returns the price and total balance of the given token based on the V2 liquidity pool.
//      * @param token Address of the token for which the price and total balance are requested.
//      * @return price The price of the token based on the V2 liquidity pool.
//      * @return tokenTotal Total balance of the token based on the V2 liquidity pool.
//      */
//     function _getPriceSolidly(
//         ISolidlyFactory factorySolidly,
//         address token
//     ) internal view returns (uint256 price, uint256 tokenTotal) {
//         require(factorySolidly != ISolidlyFactory(address(0)), "factory not set");
//         uint256 nativePrice = getNativePriceFromFactory(
//             Protocol.Solidly,
//             defaultFactoryV2,
//             IUniswapV3Factory(address(0)),
//             defaultFactorySolidly
//         );
//         if (token == wNative) {
//             /// @dev Returning high total balance for wNative to heavily weight value.
//             return (nativePrice, 1e36);
//         }

//         LocalVarsV2Price memory vars;

//         (vars.tokenReserve, vars.wNativeReserve) = _getNormalizedReservesFromFactorySolidly_Decimals(
//             factorySolidly,
//             token,
//             wNative,
//             UtilityLibrary._getTokenDecimals(token),
//             wNativeDecimals
//         );
//         vars.wNativeTotal = (vars.wNativeReserve * nativePrice) / 1e18;
//         tokenTotal += vars.tokenReserve;

//         for (uint256 i = 0; i < stableUsdTokens.length; i++) {
//             address stableUsdToken = stableUsdTokens[i];
//             (vars.tokenReserve, vars.stableUsdReserve) = _getNormalizedReservesFromFactorySolidly_Decimals(
//                 factorySolidly,
//                 token,
//                 stableUsdToken,
//                 UtilityLibrary._getTokenDecimals(token),
//                 stableUsdTokenDecimals[stableUsdToken]
//             );
//             uint256 stableUsdPrice = _getOraclePriceNormalized(stableUsdToken);

//             if (vars.stableUsdReserve > 10e18) {
//                 if (stableUsdPrice > 0) {
//                     /// @dev Weighting the USD side of the pair by the price of the USD stable token if it exists.
//                     vars.usdStableTotal += (vars.stableUsdReserve * stableUsdPrice) / 1e18;
//                 } else {
//                     vars.usdStableTotal += vars.stableUsdReserve;
//                 }
//                 tokenTotal += vars.tokenReserve;
//             }
//         }

//         if (tokenTotal == 0) {
//             return (0, 0);
//         }
//         price = ((vars.usdStableTotal + vars.wNativeTotal) * 1e18) / tokenTotal;
//     }

//     function getPriceV3(address token) public view override returns (uint256 price) {
//         (price, ) = _getPriceV3(defaultFactoryV3, token);
//     }

//     function getPriceV3FromFactory(
//         IUniswapV3Factory factoryV3,
//         address token
//     ) public view override returns (uint256 price) {
//         (price, ) = _getPriceV3(factoryV3, token);
//     }

//     /**
//      * @dev Returns the price and total balance of the given token based on the V3 liquidity pool.
//      * @param token Address of the token for which the price and total balance are requested.
//      * @return price The price of the token based on the V3 liquidity pool.
//      */
//     function _getPriceV3(
//         IUniswapV3Factory factoryV3,
//         address token
//     ) internal view returns (uint256 price, uint256 totalBalance) {
//         uint256 nativePrice = getNativePriceFromFactory(
//             Protocol.V3,
//             IApeFactory(address(0)),
//             factoryV3,
//             defaultFactorySolidly
//         );
//         if (token == wNative) {
//             /// @dev Returning high total balance for wNative to heavily weight value.
//             return (nativePrice, 1e36);
//         }

//         uint256 tempPrice;
//         uint256 totalPrice;
//         uint24[] memory fees = new uint24[](5);
//         fees[0] = 100;
//         fees[1] = 500;
//         fees[2] = 2500;
//         fees[3] = 3000;
//         fees[4] = 10000;
//         for (uint24 feeIndex = 0; feeIndex < 5; feeIndex++) {
//             uint24 fee = fees[feeIndex];
//             tempPrice = getLPPriceV3FromFactory(address(factoryV3), token, wNative, fee);
//             if (tempPrice > 0) {
//                 address pair = factoryV3.getPool(token, wNative, fee);
//                 uint256 balance = IERC20(token).balanceOf(pair);
//                 uint256 wNativeBalance = IERC20(wNative).balanceOf(pair);
//                 if (wNativeBalance > nativeLiquidityThreshold) {
//                     totalPrice += ((tempPrice * nativePrice) / 1e18) * balance;
//                     totalBalance += balance;
//                 }
//             }

//             for (uint256 i = 0; i < stableUsdTokens.length; i++) {
//                 address stableUsdToken = stableUsdTokens[i];
//                 tempPrice = getLPPriceV3FromFactory(address(factoryV3), token, stableUsdToken, fee);
//                 if (tempPrice > 0) {
//                     address pair = factoryV3.getPool(token, stableUsdToken, fee);
//                     uint256 balance = IERC20(token).balanceOf(pair);
//                     uint256 balanceStable = IERC20(stableUsdToken).balanceOf(pair);
//                     if (balanceStable > 10 * (10 ** IERC20(stableUsdToken).decimals())) {
//                         uint256 stableUsdPrice = _getOraclePriceNormalized(stableUsdToken);
//                         if (stableUsdPrice > 0) {
//                             tempPrice = (tempPrice * stableUsdPrice) / 1e18;
//                         }

//                         totalPrice += tempPrice * balance;
//                         totalBalance += balance;
//                     }
//                 }
//             }
//         }

//         if (totalBalance == 0) {
//             return (0, 0);
//         }
//         price = totalPrice / totalBalance;
//     }

//     function getPriceAlgebra(address token) public view override returns (uint256 price) {
//         (price, ) = _getPriceAlgebra(defaultFactoryAlgebra, token);
//     }

//     function getPriceAlgebraFromFactory(
//         IAlgebraFactory factoryAlgebra,
//         address token
//     ) public view override returns (uint256 price) {
//         (price, ) = _getPriceAlgebra(factoryAlgebra, token);
//     }

//     function _getPriceAlgebra(
//         IAlgebraFactory factoryAlgebra,
//         address token
//     ) internal view returns (uint256 price, uint256 totalBalance) {
//         uint256 nativePrice = getNativePriceFromFactory(
//             Protocol.Algebra,
//             IApeFactory(address(0)),
//             IUniswapV3Factory(address(0)),
//             defaultFactorySolidly
//         );
//         if (token == wNative) {
//             /// @dev Returning high total balance for wNative to heavily weight value.
//             return (nativePrice, 1e36);
//         }

//         uint256 tempPrice;
//         uint256 totalPrice;
//         tempPrice = getLPPriceAlgebraFromFactory(factoryAlgebra, token, wNative);
//         if (tempPrice > 0) {
//             address pair = factoryAlgebra.poolByPair(token, wNative);
//             uint256 balance = IERC20(token).balanceOf(pair);
//             uint256 wNativeBalance = IERC20(wNative).balanceOf(pair);
//             if (wNativeBalance > nativeLiquidityThreshold) {
//                 totalPrice += ((tempPrice * nativePrice) / 1e18) * balance;
//                 totalBalance += balance;
//             }
//         }

//         for (uint256 i = 0; i < stableUsdTokens.length; i++) {
//             address stableUsdToken = stableUsdTokens[i];
//             tempPrice = getLPPriceAlgebraFromFactory(factoryAlgebra, token, stableUsdToken);
//             if (tempPrice > 0) {
//                 address pair = factoryAlgebra.poolByPair(token, stableUsdToken);
//                 uint256 balance = IERC20(token).balanceOf(pair);
//                 uint256 balanceStable = IERC20(stableUsdToken).balanceOf(pair);
//                 if (balanceStable > 10 * (10 ** IERC20(stableUsdToken).decimals())) {
//                     uint256 stableUsdPrice = _getOraclePriceNormalized(stableUsdToken);
//                     if (stableUsdPrice > 0) {
//                         tempPrice = (tempPrice * stableUsdPrice) / 1e18;
//                     }

//                     totalPrice += tempPrice * balance;
//                     totalBalance += balance;
//                 }
//             }
//         }

//         if (totalBalance == 0) {
//             return (0, 0);
//         }
//         price = totalPrice / totalBalance;
//     }

//     /**
//      * @dev Retrieves the normalized USD price of a token from its oracle.
//      * @param token Address of the token to retrieve the price for.
//      * @return price The normalized USD price of the token from its oracle.
//      */
//     function _getOraclePriceNormalized(address token) internal view returns (uint256 price) {
//         OracleInfo memory oracleInfo = tokenOracles[token];
//         if (oracleInfo.oracleType == OracleType.CHAIN_LINK) {
//             uint256 tokenUSDPrice = _getChainlinkPriceRaw(oracleInfo.oracleAddress);
//             return UtilityLibrary._normalize(tokenUSDPrice, oracleInfo.oracleDecimals);
//         }
//         /// @dev Additional oracle types can be implemented here.
//         // else if (oracleInfo.oracleType == OracleType.<NEW_ORACLE>) { }
//         return 0;
//     }

//     /**
//      * @dev This private helper function takes in a DEX contract factory address and two token addresses (tokenA and tokenB).
//      * It returns the current price of tokenA in terms of tokenB by dividing the normalized reserve value of tokenA
//      * from the normalized reserve value of tokenB.
//      *
//      * Before calculating the price, it calls the internal _getNormalizedReservesFromFactory() function to retrieve
//      * the normalized reserves of tokenA and tokenB. If either normalized reserve value is 0, it returns 0 for the price.
//      *
//      * @param tokenA Address of one of the tokens in the pair
//      * @param tokenB Address of the other token in the pair
//      * @return priceAForB The price of tokenA in terms of tokenB
//      */
//     function _getPriceFromV2LP(
//         IApeFactory factoryV2,
//         address tokenA,
//         address tokenB
//     ) private view returns (uint256 priceAForB) {
//         (uint256 normalizedReserveA, uint256 normalizedReserveB) = _getNormalizedReservesFromFactoryV2(
//             factoryV2,
//             tokenA,
//             tokenB
//         );

//         if (normalizedReserveA == 0 || normalizedReserveA == 0) {
//             return 0;
//         }

//         // Calculate the price of tokenA in terms of tokenB by dividing the normalized reserve value of tokenA
//         // from the normalized reserve value of tokenB.
//         priceAForB = (normalizedReserveA * (10 ** 18)) / normalizedReserveB;
//     }

//     /**
//      * @dev Get normalized reserves for a given token pair from the Factory contract.
//      * @param factoryV2 The address of the V2 factory.
//      * @param tokenA The address of the first token in the pair.
//      * @param tokenB The address of the second token in the pair.
//      * @return normalizedReserveA The normalized reserve of the first token in the pair.
//      * @return normalizedReserveB The normalized reserve of the second token in the pair.
//      */
//     function _getNormalizedReservesFromFactoryV2(
//         IApeFactory factoryV2,
//         address tokenA,
//         address tokenB
//     ) internal view returns (uint256 normalizedReserveA, uint256 normalizedReserveB) {
//         address pairAddress = factoryV2.getPair(tokenA, tokenB);
//         if (pairAddress == address(0)) {
//             return (0, 0);
//         }

//         IApePair pair = IApePair(pairAddress);
//         address token0 = pair.token0();
//         address token1 = pair.token1();

//         uint8 decimals0 = IERC20(token0).decimals();
//         uint8 decimals1 = IERC20(token1).decimals();

//         return _getNormalizedReservesFromPair_Decimals(pairAddress, token0, token1, decimals0, decimals1);
//     }

//     /**
//      * @dev Get normalized reserves for a given token pair from the ApeSwap Factory contract, specifying decimals.
//      * @param factoryV2 The address of the V2 factory.
//      * @param tokenA The address of the first token in the pair.
//      * @param tokenB The address of the second token in the pair.
//      * @param decimalsA The number of decimals for the first token in the pair.
//      * @param decimalsB The number of decimals for the second token in the pair.
//      * @return normalizedReserveA The normalized reserve of the first token in the pair.
//      * @return normalizedReserveB The normalized reserve of the second token in the pair.
//      */
//     function _getNormalizedReservesFromFactoryV2_Decimals(
//         IApeFactory factoryV2,
//         address tokenA,
//         address tokenB,
//         uint8 decimalsA,
//         uint8 decimalsB
//     ) internal view returns (uint256 normalizedReserveA, uint256 normalizedReserveB) {
//         address pairAddress = factoryV2.getPair(tokenA, tokenB);
//         if (pairAddress == address(0)) {
//             return (0, 0);
//         }
//         return _getNormalizedReservesFromPair_Decimals(pairAddress, tokenA, tokenB, decimalsA, decimalsB);
//     }

//     /**
//      * @dev Get normalized reserves for a given token pair from the ApeSwap Factory contract, specifying decimals.
//      * @param factorySolidly The address of the V2 factory.
//      * @param tokenA The address of the first token in the pair.
//      * @param tokenB The address of the second token in the pair.
//      * @param decimalsA The number of decimals for the first token in the pair.
//      * @param decimalsB The number of decimals for the second token in the pair.
//      * @return normalizedReserveA The normalized reserve of the first token in the pair.
//      * @return normalizedReserveB The normalized reserve of the second token in the pair.
//      */
//     function _getNormalizedReservesFromFactorySolidly_Decimals(
//         ISolidlyFactory factorySolidly,
//         address tokenA,
//         address tokenB,
//         uint8 decimalsA,
//         uint8 decimalsB
//     ) internal view returns (uint256 normalizedReserveA, uint256 normalizedReserveB) {
//         /// @dev Defaulting to stable == false
//         try factorySolidly.getPair(tokenA, tokenB, false) returns (address pairAddress) {
//             if (pairAddress == address(0)) {
//                 return (0, 0);
//             }
//             return _getNormalizedReservesFromPair_Decimals(pairAddress, tokenA, tokenB, decimalsA, decimalsB);
//         } catch {}
//         try factorySolidly.getPool(tokenA, tokenB, false) returns (address pairAddress) {
//             if (pairAddress == address(0)) {
//                 return (0, 0);
//             }
//             return _getNormalizedReservesFromPair_Decimals(pairAddress, tokenA, tokenB, decimalsA, decimalsB);
//         } catch {}
//         revert("No pair found");
//     }

//     /**
//      * @dev Get normalized reserves for a given token pair from the ApeSwap Factory contract, specifying decimals.
//      * @param factoryXFAI The address of the XFAI factory.
//      * @param decimalsA The number of decimals for the first token in the pair.
//      * @param decimalsB The number of decimals for the second token in the pair.
//      * @return normalizedReserveA The normalized reserve of the first token in the pair.
//      * @return normalizedReserveB The normalized reserve of the second token in the pair.
//      */
//     function _getNormalizedReservesFromFactoryXFAI_Decimals(
//         IXfaiFactory factoryXFAI,
//         address tokenA,
//         uint8 decimalsA,
//         uint8 decimalsB
//     ) internal view returns (uint256 normalizedReserveA, uint256 normalizedReserveB) {
//         address pairAddress = factoryXFAI.getPool(tokenA);
//         if (pairAddress == address(0)) {
//             return (0, 0);
//         }
//         return _getNormalizedReservesFromXFAIPair_Decimals(pairAddress, decimalsA, decimalsB);
//     }

//     /**
//      * @dev This internal function takes in a pair address, two token addresses (tokenA and tokenB), and their respective decimals.
//      * It returns the normalized reserves for each token in the pair.
//      *
//      * This function uses the IApePair interface to get the current reserves of the given token pair
//      * If successful, it returns the normalized reserves for each token in the pair by calling _normalize() on
//      * the reserve values. The order of the returned normalized reserve values depends on the lexicographic ordering
//      * of tokenA and tokenB.
//      *
//      * @param pair Address of the liquidity pool contract representing the token pair
//      * @param tokenA Address of one of the tokens in the pair. Assumed to be a valid address in the pair to save on gas.
//      * @param tokenB Address of the other token in the pair. Assumed to be a valid address in the pair to save on gas.
//      * @param decimalsA The number of decimals for tokenA
//      * @param decimalsB The number of decimals for tokenB
//      * @return normalizedReserveA The normalized reserve value for tokenA
//      * @return normalizedReserveB The normalized reserve value for tokenB
//      */
//     function _getNormalizedReservesFromPair_Decimals(
//         address pair,
//         address tokenA,
//         address tokenB,
//         uint8 decimalsA,
//         uint8 decimalsB
//     ) internal view returns (uint256 normalizedReserveA, uint256 normalizedReserveB) {
//         (bool success, bytes memory returnData) = pair.staticcall(abi.encodeWithSignature("getReserves()"));

//         if (success) {
//             try this.decodeReservesWithLP(returnData) returns (uint112 reserve0, uint112 reserve1, uint32) {
//                 if (UtilityLibrary._isSorted(tokenA, tokenB)) {
//                     return (
//                         UtilityLibrary._normalize(reserve0, decimalsA),
//                         UtilityLibrary._normalize(reserve1, decimalsB)
//                     );
//                 } else {
//                     return (
//                         UtilityLibrary._normalize(reserve1, decimalsA),
//                         UtilityLibrary._normalize(reserve0, decimalsB)
//                     );
//                 }
//             } catch {
//                 (success, returnData) = pair.staticcall(abi.encodeWithSignature("getFictiveReserves()"));
//                 try this.decodeReservesWithoutLP(returnData) returns (uint256 reserve0, uint256 reserve1) {
//                     if (UtilityLibrary._isSorted(tokenA, tokenB)) {
//                         return (
//                             UtilityLibrary._normalize(reserve0, decimalsA),
//                             UtilityLibrary._normalize(reserve1, decimalsB)
//                         );
//                     } else {
//                         return (
//                             UtilityLibrary._normalize(reserve1, decimalsA),
//                             UtilityLibrary._normalize(reserve0, decimalsB)
//                         );
//                     }
//                 } catch {
//                     return (0, 0);
//                 }
//             }
//         } else {
//             return (0, 0);
//         }
//     }

//     function decodeReservesWithLP(
//         bytes memory data
//     ) public pure returns (uint112 reserve0, uint112 reserve1, uint32 lp) {
//         return abi.decode(data, (uint112, uint112, uint32));
//     }

//     function decodeReservesWithoutLP(bytes memory data) public pure returns (uint256 reserve0, uint256 reserve1) {
//         return abi.decode(data, (uint256, uint256));
//     }

//     function _getNormalizedReservesFromXFAIPair_Decimals(
//         address pair,
//         uint8 decimalsA,
//         uint8 decimalsB
//     ) internal view returns (uint256 normalizedReserveA, uint256 normalizedReserveB) {
//         try IXfaiPool(pair).getStates() returns (uint reserve0, uint reserve1, uint) {
//             return (UtilityLibrary._normalize(reserve0, decimalsA), UtilityLibrary._normalize(reserve1, decimalsB));
//         } catch {
//             return (0, 0);
//         }
//     }
// }
