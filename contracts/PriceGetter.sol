// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.16;

import "./token-lib/IERC20.sol";
import "./swap-v2-lib/IApePair.sol";
import "./swap-v2-lib/IApeFactory.sol";
import "./chainlink/ChainlinkOracle.sol";
import "./IPriceGetter.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";
import "@uniswap/v3-core/contracts/libraries/FullMath.sol";

/**
DISCLAIMER:
This smart contract is provided for user interface purposes only and is not intended to be used for smart contract logic. 
Any attempt to rely on this code for the execution of a smart contract may result in unexpected behavior, 
errors, or other issues that could lead to financial loss or other damages. 
The user assumes all responsibility and risk for proper usage. 
The developer and associated parties make no warranties and are not liable for any damages incurred.
*/

contract PriceGetter is IPriceGetter, ChainlinkOracle {
    /*
    // NOTE: 
    Gas is actually an important consideration for this contract because it limits how many of these calls can be batched together in a single multicall read.
    1. _getNormalizedReservesFromFactory_Decimals: The purpose of these functions are to be able to pass in cached decimals to avoid needing to make an extra calls to the token contracts 

    TODO TASKS
    - [x] Implement base features of IPriceGetter with single router (may be able to move away from the interface a bit)
    - [x] Implement Chainlink price feed
    - [ ] Extend to include dynamic router (=factory)
    - [x] Ordering of functions, styling, comments, etc
    - [x] Fork testing?
    */
    enum OracleType {
        NONE,
        CHAIN_LINK
    }

    struct OracleInfo {
        OracleType oracleType;
        address oracleAddress;
        uint8 oracleDecimals;
    }

    struct LocalVars {
        uint256 usdStableTotal;
        uint256 wNativeReserve;
        uint256 wNativeTotal;
        uint256 tokenReserve;
        uint256 stableUsdReserve;
    }

    // TODO: Possibly use an enumerable set
    mapping(address => OracleInfo) public tokenOracles;
    address public wNative;
    address[] public stableUsdTokens;
    mapping(address => uint8) public stableUsdTokenDecimals;
    IApeFactory factoryV2;
    IUniswapV3Factory factoryV3;

    /**
     * @dev This contract constructor takes in several parameters which includes the wrapped native token address,
     * an array of addresses for stable USD tokens, an array of addresses for oracle tokens, and an array of addresses
     * for oracles.
     *
     * @param _wNative Address of the wrapped native token
     * @param _factoryV2 Address of factoryV2
     * @param _factoryV3 Address of factoryV3
     * @param _stableUsdTokens Array of stable USD token addresses
     * @param _oracleTokens Array of oracle token addresses
     * @param _oracles Array of oracle addresses
     */
    constructor(
        address _wNative,
        IApeFactory _factoryV2,
        IUniswapV3Factory _factoryV3,
        address[] memory _stableUsdTokens,
        address[] memory _oracleTokens,
        address[] memory _oracles
    ) {
        // Check if the lengths of the oracleTokens and oracles arrays match
        require(_oracleTokens.length == _oracles.length, "Oracles length mismatch");

        // Loop through the oracleTokens array and set the oracle address for each oracle token using the _setTokenOracle() internal helper function
        for (uint256 i = 0; i < _oracleTokens.length; i++) {
            /// @dev Assumes OracleType.CHAIN_LINK
            _setTokenOracle(_oracleTokens[i], _oracles[i], OracleType.CHAIN_LINK);
        }

        // Add the stable USD tokens to the stableCoins array using the _addStableUsdTokens() internal helper function
        _addStableUsdTokens(_stableUsdTokens);

        // Set the wrapped native token (wNative) address
        wNative = _wNative;

        // Set the factory addresses
        factoryV2 = _factoryV2;
        factoryV3 = _factoryV3;
    }

    /** SETTERS */

    /**
     * @dev Adds new stable USD tokens to the list of supported stable USD tokens.
     * @param newStableUsdTokens An array of addresses representing the new stable USD tokens to add.
     */
    function _addStableUsdTokens(address[] memory newStableUsdTokens) internal {
        for (uint256 i = 0; i < newStableUsdTokens.length; i++) {
            address stableUsdToken = newStableUsdTokens[i];
            stableUsdTokens.push(newStableUsdTokens[i]);
            require(stableUsdTokenDecimals[stableUsdToken] == 0, "PriceGetter: Stable token already added");
            stableUsdTokenDecimals[stableUsdToken] = _getTokenDecimals(stableUsdToken);
        }
    }

    /**
     * @dev Sets the oracle address and type for a specified token.
     * @param token The address of the token to set the oracle for.
     * @param oracleAddress The address of the oracle contract.
     * @param oracleType The type of the oracle (e.g. Chainlink, Uniswap).
     */
    function _setTokenOracle(
        address token,
        address oracleAddress,
        OracleType oracleType
    ) internal {
        uint8 oracleDecimals = 18;
        try IERC20(oracleAddress).decimals() returns (uint8 dec) {
            oracleDecimals = dec;
        } catch {}

        tokenOracles[token] = OracleInfo({
            oracleType: oracleType,
            oracleAddress: oracleAddress,
            oracleDecimals: oracleDecimals
        });
    }

    /** GETTERS */

    // ===== Get LP Prices =====

    /**
     * @dev Returns the price of a liquidity pool
     * @param lp The address of the LP token contract.
     * @return price The current price of the LP token.
     */
    function getLPPriceV2(address lp) public view override returns (uint256 price) {
        //if not a LP, handle as a standard token
        try IApePair(lp).getReserves() returns (uint112 reserve0, uint112 reserve1, uint32) {
            address token0 = IApePair(lp).token0();
            address token1 = IApePair(lp).token1();
            uint256 totalSupply = IApePair(lp).totalSupply();

            //price0*reserve0+price1*reserve1

            uint256 totalValue = getPrice(token0, Protocol.V2, 0) *
                reserve0 +
                getPrice(token1, Protocol.V2, 0) *
                reserve1;

            return totalValue / totalSupply;
        } catch {
            return getPrice(lp, Protocol.V2, 0);
        }
    }

    /**
     * @dev Returns the prices of multiple LP tokens using the getLPPriceV2 function.
     * @param tokens An array of LP token addresses to get the prices for.
     * @return prices An array of prices for the specified LP tokens.
     */
    function getLPPricesV2(address[] calldata tokens) external view override returns (uint256[] memory prices) {
        prices = new uint256[](tokens.length);
        for (uint256 i; i < prices.length; i++) {
            address token = tokens[i];
            prices[i] = getLPPriceV2(token);
        }
    }

    /**
     * @dev Returns the price of an LP token.
     * @param token0 The address of the first token in the LP pair.
     * @param token1 The address of the second token in the LP pair.
     * @param fee The Uniswap V3 pool fee.
     * @param secondsAgo The time in seconds in the past to get the price for.
     * @return price The price of the LP token.
     */
    function getLPPriceV3(
        address token0,
        address token1,
        uint24 fee,
        uint32 secondsAgo
    ) public view returns (uint256 price) {
        address tokenPegPair = IUniswapV3Factory(factoryV3).getPool(token0, token1, fee);

        // if the address has no contract deployed, the pair doesn't exist
        uint256 size;

        assembly {
            size := extcodesize(tokenPegPair)
        }

        if (size == 0) return 0;

        uint256 sqrtPriceX96;

        if (secondsAgo == 0) {
            // return the current price if secondsAgo == 0
            (sqrtPriceX96, , , , , , ) = IUniswapV3Pool(tokenPegPair).slot0();
        } else {
            uint32[] memory secondsAgos = new uint32[](2);
            secondsAgos[0] = secondsAgo; // from (before)
            secondsAgos[1] = 0; // to (now)

            (int56[] memory tickCumulatives, ) = IUniswapV3Pool(tokenPegPair).observe(secondsAgos);

            // tick(imprecise as it's an integer) to price
            sqrtPriceX96 = TickMath.getSqrtRatioAtTick(
                int24((tickCumulatives[1] - tickCumulatives[0]) / int56(int32(secondsAgo)))
            );
        }

        uint256 token0Decimals;
        try IERC20(token0).decimals() returns (uint8 dec) {
            token0Decimals = dec;
        } catch {
            token0Decimals = 18;
        }

        uint256 token1Decimals;
        try IERC20(token1).decimals() returns (uint8 dec) {
            token1Decimals = dec;
        } catch {
            token1Decimals = 18;
        }

        //Makes sure it doesn't overflow
        uint256 decimalCorrection = 0;
        if (sqrtPriceX96 >= 340282366920938463463374607431768211455) {
            sqrtPriceX96 = sqrtPriceX96 / 1e3;
            decimalCorrection = 6;
        }

        if (token1 < token0) {
            price =
                (2**192) /
                ((sqrtPriceX96)**2 / uint256(10**(token0Decimals + 18 - token1Decimals - decimalCorrection)));
        } else {
            price =
                ((sqrtPriceX96)**2) /
                ((2**192) / uint256(10**(token0Decimals + 18 - token1Decimals - decimalCorrection)));
        }
    }

    /**
     * @dev Returns the prices of multiple LP tokens using the getLPPriceV3 function.
     * @param tokens0 An array of addresses representing the first tokens in the LP pairs to get the prices for.
     * @param tokens1 An array of addresses representing the second tokens in the LP pairs to get the prices for.
     * @param fees An array of Uniswap V3 pool fees for each LP pair.
     * @param secondsAgo The time in seconds in the past to get the price for.
     * @return prices An array of prices for the specified LP tokens.
     */
    function getLPPricesV3(
        address[] calldata tokens0,
        address[] calldata tokens1,
        uint24[] calldata fees,
        uint24 secondsAgo
    ) external view override returns (uint256[] memory prices) {
        prices = new uint256[](tokens0.length);
        for (uint256 i; i < prices.length; i++) {
            address token0 = tokens0[i];
            address token1 = tokens1[i];
            uint24 fee = fees[i];
            prices[i] = getLPPriceV3(token0, token1, fee, secondsAgo);
        }
    }

    // ===== Get Native Prices =====

    /**
     * @dev Returns the current price of wNative in USD based on the given protocol and time delta.
     * @param protocol The protocol version to use
     * @param secondsAgo The time delta (in seconds) to use for V3 pricing
     * @return nativePrice The current price of wNative in USD.
     */
    function getNativePrice(Protocol protocol, uint32 secondsAgo) public view returns (uint256 nativePrice) {
        uint256 oraclePrice = _getOraclePriceNormalized(wNative);
        if (oraclePrice > 0) {
            return oraclePrice;
        }

        if (protocol == Protocol.Both) {
            (uint256 nativeV3Price, uint256 totalNativeV3) = _getNativePriceV3(secondsAgo);
            (uint256 nativeV2Price, uint256 totalNativeV2) = _getNativePriceV2();
            if (totalNativeV3 + totalNativeV2 == 0) return 0;
            return (nativeV3Price * totalNativeV3 + nativeV2Price * totalNativeV2) / (totalNativeV3 + totalNativeV2);
        } else if (protocol == Protocol.V2) {
            (uint256 nativeV2Price, ) = _getNativePriceV2();
            return nativeV2Price;
        } else if (protocol == Protocol.V3) {
            (uint256 nativeV3Price, ) = _getNativePriceV3(secondsAgo);
            return nativeV3Price;
        } else {
            revert("Invalid protocol");
        }
    }

    /**
     * @dev Calculates the price of wNative using V2 pricing.
     * Compares multiple stable pools and weights by their oracle price.
     * @return price price of wNative in USD
     * @return wNativeTotal The total amount of wNative in the pools.
     */
    function _getNativePriceV2() internal view returns (uint256 price, uint256 wNativeTotal) {
        /// @dev This method calculates the price of wNative by comparing multiple stable pools and weighting by their oracle price
        uint256 usdStableTotal = 0;
        for (uint256 i = 0; i < stableUsdTokens.length; i++) {
            address stableUsdToken = stableUsdTokens[i];
            (uint256 wNativeReserve, uint256 stableUsdReserve) = _getNormalizedReservesFromFactory_Decimals(
                wNative,
                stableUsdToken,
                _getTokenDecimals(wNative),
                stableUsdTokenDecimals[stableUsdToken]
            );
            uint256 stableUsdPrice = _getOraclePriceNormalized(stableUsdToken);
            if (stableUsdPrice > 0) {
                /// @dev Weighting the USD side of the pair by the price of the USD stable token if it exists.
                usdStableTotal += (stableUsdReserve * stableUsdPrice) / 1e18;
            } else {
                usdStableTotal += stableUsdReserve;
            }
            wNativeTotal += wNativeReserve;
        }

        price = (usdStableTotal * 1e18) / wNativeTotal;
    }

    /**
     * @dev Calculates the price of wNative using V3 pricing.
     * Uses Uniswap V3 pools with various fees and stable tokens.
     * @param secondsAgo The time delta (in seconds) to use for the Uniswap V3 oracle.
     * @return price The price of wNative in USD
     * @return wNativeTotal The total amount of wNative in the pools.
     */
    function _getNativePriceV3(uint32 secondsAgo) internal view returns (uint256 price, uint256 wNativeTotal) {
        uint256 totalPrice;

        uint24[] memory fees = new uint24[](4);
        fees[0] = 100;
        fees[1] = 500;
        fees[2] = 3000;
        fees[3] = 10000;
        for (uint24 feeIndex = 0; feeIndex < 4; feeIndex++) {
            uint24 fee = fees[feeIndex];
            for (uint256 i = 0; i < stableUsdTokens.length; i++) {
                address stableUsdToken = stableUsdTokens[i];
                price = getLPPriceV3(wNative, stableUsdToken, fee, secondsAgo);
                uint256 stableUsdPrice = _getOraclePriceNormalized(stableUsdToken);
                if (stableUsdPrice > 0) {
                    price *= stableUsdPrice / 1e18;
                }
                if (price > 0) {
                    address pair = factoryV3.getPool(wNative, stableUsdToken, fee);
                    uint256 balance = IERC20(wNative).balanceOf(pair);
                    totalPrice += price * balance;
                    wNativeTotal += balance;
                }
            }
        }

        if (wNativeTotal == 0) {
            return (0, wNativeTotal);
        }
        price = totalPrice / wNativeTotal;
    }

    // ===== Get Token Prices =====

    /**
     * @dev Returns the current price of the given token based on the specified protocol and time interval.
     * If protocol is set to 'Both', the price is calculated as a weighted average of the V2 and V3 prices,
     * where the weights are the respective liquidity pools. If protocol is set to 'V2' or 'V3', the price
     * is calculated based on the respective liquidity pool.
     * @param token Address of the token for which the price is requested.
     * @param protocol The liquidity protocol used to calculate the price.
     * @param secondsAgo The time interval in seconds for which the price is calculated.
     * @return price The price of the token in USD.
     */
    function getPrice(
        address token,
        Protocol protocol,
        uint32 secondsAgo
    ) public view returns (uint256 price) {
        if (protocol == Protocol.Both) {
            (uint256 ETHV3Price, uint256 totalETHV3) = _getPriceV3(token, secondsAgo);
            (uint256 ETHV2Price, uint256 totalETHV2) = _getPriceV2(token);
            return (ETHV3Price * totalETHV3 + ETHV2Price * totalETHV2) / (totalETHV3 + totalETHV2);
        } else if (protocol == Protocol.V2) {
            (uint256 ETHV2Price, ) = _getPriceV2(token);
            return ETHV2Price;
        } else if (protocol == Protocol.V3) {
            (uint256 ETHV3Price, ) = _getPriceV3(token, secondsAgo);
            return ETHV3Price;
        } else {
            revert("Invalid protocol");
        }
    }

    /**
     * @dev Returns an array of prices for the given array of tokens based on the specified protocol and time interval.
     * @param tokens An array of token addresses for which prices are requested.
     * @param protocol The liquidity protocol used to calculate the prices.
     * @param secondsAgo The time interval in seconds for which the prices are calculated.
     * @return prices An array of prices for the given tokens in USD.
     */
    function getPrices(
        address[] calldata tokens,
        Protocol protocol,
        uint32 secondsAgo
    ) external view override returns (uint256[] memory prices) {
        prices = new uint256[](tokens.length);

        for (uint256 i; i < prices.length; i++) {
            address token = tokens[i];
            prices[i] = getPrice(token, protocol, secondsAgo);
        }
    }

    /**
     * @dev Returns the price and total balance of the given token based on the V2 liquidity pool.
     * @param token Address of the token for which the price and total balance are requested.
     * @return price The price of the token based on the V2 liquidity pool.
     * @return tokenTotal Total balance of the token based on the V2 liquidity pool.
     */
    function _getPriceV2(address token) internal view returns (uint256 price, uint256 tokenTotal) {
        LocalVars memory vars;

        (vars.tokenReserve, vars.wNativeReserve) = _getNormalizedReservesFromFactory_Decimals(
            token,
            wNative,
            _getTokenDecimals(token),
            _getTokenDecimals(wNative)
        );
        vars.wNativeTotal = (vars.wNativeReserve * getNativePrice(Protocol.V2, 0)) / 1e18;
        tokenTotal += vars.tokenReserve;

        for (uint256 i = 0; i < stableUsdTokens.length; i++) {
            address stableUsdToken = stableUsdTokens[i];
            (vars.tokenReserve, vars.stableUsdReserve) = _getNormalizedReservesFromFactory_Decimals(
                token,
                stableUsdToken,
                _getTokenDecimals(token),
                stableUsdTokenDecimals[stableUsdToken]
            );
            uint256 stableUsdPrice = _getOraclePriceNormalized(stableUsdToken);
            if (stableUsdPrice > 0) {
                /// @dev Weighting the USD side of the pair by the price of the USD stable token if it exists.
                vars.usdStableTotal += (vars.stableUsdReserve * stableUsdPrice) / 1e18;
            } else {
                vars.usdStableTotal += vars.stableUsdReserve;
            }
            tokenTotal += vars.tokenReserve;
        }
        price = ((vars.usdStableTotal + vars.wNativeTotal) * 1e18) / tokenTotal;
    }

    /**
     * @dev Returns the price and total balance of the given token based on the V3 liquidity pool.
     * @param token Address of the token for which the price and total balance are requested.
     * @param secondsAgo The time interval in seconds for which the price and total balance are requested.
     * @return price The price of the token based on the V3 liquidity pool.
     * @return totalBalance Total balance of the token based on the V3 liquidity pool.
     */
    function _getPriceV3(address token, uint32 secondsAgo) internal view returns (uint256 price, uint256 totalBalance) {
        uint256 tempPrice;
        uint256 totalPrice;
        uint256 nativePrice = getNativePrice(Protocol.V3, secondsAgo);
        uint24[] memory fees = new uint24[](4);
        fees[0] = 100;
        fees[1] = 500;
        fees[2] = 3000;
        fees[3] = 10000;
        for (uint24 feeIndex = 0; feeIndex < 4; feeIndex++) {
            uint24 fee = fees[feeIndex];
            tempPrice = getLPPriceV3(token, wNative, fee, secondsAgo);
            if (tempPrice > 0) {
                address pair = factoryV3.getPool(token, wNative, fee);
                uint256 balance = IERC20(token).balanceOf(pair);
                totalPrice += ((tempPrice * nativePrice) / 1e18) * balance;
                totalBalance += balance;
            }

            for (uint256 i = 0; i < stableUsdTokens.length; i++) {
                address stableUsdToken = stableUsdTokens[i];
                tempPrice = getLPPriceV3(token, stableUsdToken, fee, secondsAgo);
                if (tempPrice > 0) {
                    uint256 stableUsdPrice = _getOraclePriceNormalized(stableUsdToken);
                    if (stableUsdPrice > 0) {
                        tempPrice *= stableUsdPrice / 1e18;
                    }

                    address pair = factoryV3.getPool(token, stableUsdToken, fee);
                    uint256 balance = IERC20(token).balanceOf(pair);
                    totalPrice += tempPrice * balance;
                    totalBalance += balance;
                }
            }
        }

        if (totalBalance == 0) {
            return (0, totalBalance);
        }
        price = totalPrice / totalBalance;
    }

    /**
     * @dev Retrieves the normalized USD price of a token from its oracle.
     * @param token Address of the token to retrieve the price for.
     * @return price The normalized USD price of the token from its oracle.
     */
    function _getOraclePriceNormalized(address token) internal view returns (uint256 price) {
        OracleInfo memory oracleInfo = tokenOracles[token];
        if (oracleInfo.oracleType == OracleType.CHAIN_LINK) {
            uint256 tokenUSDPrice = _getChainlinkPriceRaw(oracleInfo.oracleAddress);
            return _normalize(tokenUSDPrice, oracleInfo.oracleDecimals);
        }
        /// @dev Additional oracle types can be implemented here.
        // else if (oracleInfo.oracleType == OracleType.<NEW_ORACLE>) { }
        return 0;
    }

    /**
     * @dev This private helper function takes in a DEX contract factory address and two token addresses (tokenA and tokenB).
     * It returns the current price of tokenA in terms of tokenB by dividing the normalized reserve value of tokenA
     * from the normalized reserve value of tokenB.
     *
     * Before calculating the price, it calls the internal _getNormalizedReservesFromFactory() function to retrieve
     * the normalized reserves of tokenA and tokenB. If either normalized reserve value is 0, it returns 0 for the price.
     *
     * @param tokenA Address of one of the tokens in the pair
     * @param tokenB Address of the other token in the pair
     * @return priceAForB The price of tokenA in terms of tokenB
     */
    // TODO: Make public? The idea here is that this function allows for path pricing. Where the front end can send a dynamic path and this could find the price between two addresses in the path.
    function _getPriceFromV2LP(address tokenA, address tokenB) private view returns (uint256 priceAForB) {
        (uint256 normalizedReserveA, uint256 normalizedReserveB) = _getNormalizedReservesFromFactory(tokenA, tokenB);

        if (normalizedReserveA == 0 || normalizedReserveA == 0) {
            return 0;
        }

        // Calculate the price of tokenA in terms of tokenB by dividing the normalized reserve value of tokenA
        // from the normalized reserve value of tokenB.
        priceAForB = (normalizedReserveA * (10**18)) / normalizedReserveB;
    }

    /**
     * @dev Get normalized reserves for a given token pair from the Factory contract.
     * @param tokenA The address of the first token in the pair.
     * @param tokenB The address of the second token in the pair.
     * @return normalizedReserveA The normalized reserve of the first token in the pair.
     * @return normalizedReserveB The normalized reserve of the second token in the pair.
     */
    function _getNormalizedReservesFromFactory(address tokenA, address tokenB)
        internal
        view
        returns (uint256 normalizedReserveA, uint256 normalizedReserveB)
    {
        address pairAddress = factoryV2.getPair(tokenA, tokenB);
        if (pairAddress == address(0)) {
            return (0, 0);
        }

        IApePair pair = IApePair(pairAddress);
        address token0 = pair.token0();
        address token1 = pair.token1();

        uint8 decimals0 = IERC20(token0).decimals();
        uint8 decimals1 = IERC20(token1).decimals();

        return _getNormalizedReservesFromPair_Decimals(pairAddress, token0, token1, decimals0, decimals1);
    }

    /**
     * @dev Get normalized reserves for a given token pair from the ApeSwap Factory contract, specifying decimals.
     * @param tokenA The address of the first token in the pair.
     * @param tokenB The address of the second token in the pair.
     * @param decimalsA The number of decimals for the first token in the pair.
     * @param decimalsB The number of decimals for the second token in the pair.
     * @return normalizedReserveA The normalized reserve of the first token in the pair.
     * @return normalizedReserveB The normalized reserve of the second token in the pair.
     */
    function _getNormalizedReservesFromFactory_Decimals(
        address tokenA,
        address tokenB,
        uint8 decimalsA,
        uint8 decimalsB
    ) internal view returns (uint256 normalizedReserveA, uint256 normalizedReserveB) {
        address pairAddress = factoryV2.getPair(tokenA, tokenB);
        if (pairAddress == address(0)) {
            return (0, 0);
        }
        return _getNormalizedReservesFromPair_Decimals(pairAddress, tokenA, tokenB, decimalsA, decimalsB);
    }

    /**
     * @dev This internal function takes in a pair address, two token addresses (tokenA and tokenB), and their respective decimals.
     * It returns the normalized reserves for each token in the pair.
     *
     * This function uses the IApePair interface to get the current reserves of the given token pair
     * If successful, it returns the normalized reserves for each token in the pair by calling _normalize() on
     * the reserve values. The order of the returned normalized reserve values depends on the lexicographic ordering
     * of tokenA and tokenB.
     *
     * @param pair Address of the liquidity pool contract representing the token pair
     * @param tokenA Address of one of the tokens in the pair
     * @param tokenB Address of the other token in the pair
     * @param decimalsA The number of decimals for tokenA
     * @param decimalsB The number of decimals for tokenB
     * @return normalizedReserveA The normalized reserve value for tokenA
     * @return normalizedReserveB The normalized reserve value for tokenB
     */
    function _getNormalizedReservesFromPair_Decimals(
        address pair,
        address tokenA,
        address tokenB,
        uint8 decimalsA,
        uint8 decimalsB
    ) internal view returns (uint256 normalizedReserveA, uint256 normalizedReserveB) {
        try IApePair(pair).getReserves() returns (uint112 reserve0, uint112 reserve1, uint32) {
            if (_isSorted(tokenA, tokenB)) {
                return (_normalize(reserve0, decimalsA), _normalize(reserve1, decimalsB));
            } else {
                return (_normalize(reserve1, decimalsA), _normalize(reserve0, decimalsB));
            }
        } catch {
            return (0, 0);
        }
    }

    function _isSorted(address tokenA, address tokenB) internal pure returns (bool isSorted) {
        //  (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        isSorted = tokenA < tokenB ? true : false;
    }

    function _getTokenDecimals(address token) internal view returns (uint8 decimals) {
        try IERC20(token).decimals() returns (uint8 dec) {
            decimals = dec;
        } catch {
            decimals = 18;
        }
    }

    /// @notice Normalize the amount of a token to wei or 1e18
    function _normalizeToken(uint256 amount, address token) private view returns (uint256) {
        return _normalize(amount, _getTokenDecimals(token));
    }

    /// @notice Normalize the amount passed to wei or 1e18 decimals
    function _normalize(uint256 amount, uint8 decimals) private pure returns (uint256) {
        return (amount * (10**18)) / (10**decimals);
    }
}
