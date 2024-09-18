// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.16;

import "./IPriceGetterExtension.sol";
import "../IPriceGetter.sol";
import "../lib/UtilityLibrary.sol";
// Updated imports to Solidly-specific interfaces
import "../interfaces/ISolidlyPair.sol";
import "../interfaces/ISolidlyFactory.sol";

contract PriceGetterSolidly is IPriceGetterExtension {
    struct LocalVarsSolidlyPrice {
        uint256 usdStableTotal;
        uint256 wrappedNativeReserve;
        uint256 wrappedNativeTotal;
        uint256 tokenReserve;
        uint256 stableUsdReserve;
    }

    // ========== Get Token Prices ==========

    function getTokenPrice(
        address token,
        address factory,
        IPriceGetter mainPriceGetter,
        IPriceGetter.TokenAndDecimals memory wrappedNative,
        IPriceGetter.TokenAndDecimals[] memory stableUsdTokens,
        uint256 nativeLiquidityThreshold
    ) public view returns (uint256 price) {
        ISolidlyFactory factorySolidly = ISolidlyFactory(factory);
        uint256 nativePrice = mainPriceGetter.getNativePrice(IPriceGetter.Protocol.Solidly, address(factorySolidly));
        if (token == wrappedNative.tokenAddress) {
            /// @dev Returning high total balance for wrappedNative to heavily weight value.
            return nativePrice;
        }

        LocalVarsSolidlyPrice memory vars;

        (vars.tokenReserve, vars.wrappedNativeReserve) = _getNormalizedReservesFromFactorySolidly_Decimals(
            factorySolidly,
            token,
            wrappedNative.tokenAddress,
            UtilityLibrary._getTokenDecimals(token),
            wrappedNative.decimals
        );
        vars.wrappedNativeTotal = (vars.wrappedNativeReserve * nativePrice) / 1e18;
        uint256 tokenTotal = vars.tokenReserve;

        for (uint256 i = 0; i < stableUsdTokens.length; i++) {
            IPriceGetter.TokenAndDecimals memory stableUsdToken = stableUsdTokens[i];
            (vars.tokenReserve, vars.stableUsdReserve) = _getNormalizedReservesFromFactorySolidly_Decimals(
                factorySolidly,
                token,
                stableUsdToken.tokenAddress,
                UtilityLibrary._getTokenDecimals(token),
                stableUsdToken.decimals
            );
            uint256 stableUsdPrice = mainPriceGetter.getOraclePriceNormalized(stableUsdToken.tokenAddress);

            if (vars.stableUsdReserve > 10e18) {
                if (stableUsdPrice > 0) {
                    /// @dev Weighting the USD side of the pair by the price of the USD stable token if it exists.
                    vars.usdStableTotal += (vars.stableUsdReserve * stableUsdPrice) / 1e18;
                } else {
                    vars.usdStableTotal += vars.stableUsdReserve;
                }
                tokenTotal += vars.tokenReserve;
            }
        }

        if (tokenTotal == 0) {
            return 0;
        }
        price = ((vars.usdStableTotal + vars.wrappedNativeTotal) * 1e18) / tokenTotal;
    }

    // ========== LP PRICE ==========

    function getLPPrice(
        address lp,
        address factory,
        IPriceGetter mainPriceGetter,
        IPriceGetter.TokenAndDecimals memory wrappedNative,
        IPriceGetter.TokenAndDecimals[] memory stableUsdTokens,
        uint256 nativeLiquidityThreshold
    ) public view override returns (uint256 price) {
        // If not a LP, handle as a standard token
        try ISolidlyPair(lp).getReserves() returns (uint256 reserve0, uint256 reserve1, uint256) {
            address token0 = ISolidlyPair(lp).token0();
            address token1 = ISolidlyPair(lp).token1();
            uint256 totalSupply = ISolidlyPair(lp).totalSupply();

            // price0 * reserve0 + price1 * reserve1
            uint256 token0Price = getTokenPrice(
                token0,
                factory,
                mainPriceGetter,
                wrappedNative,
                stableUsdTokens,
                nativeLiquidityThreshold
            );
            uint256 token1Price = getTokenPrice(
                token1,
                factory,
                mainPriceGetter,
                wrappedNative,
                stableUsdTokens,
                nativeLiquidityThreshold
            );
            reserve0 = UtilityLibrary._normalizeToken(reserve0, token0);
            reserve1 = UtilityLibrary._normalizeToken(reserve1, token1);
            uint256 totalValue = (token0Price * uint256(reserve0)) + (token1Price * uint256(reserve1));

            return totalValue / totalSupply;
        } catch {
            /// @dev If the pair is not a valid LP, return the price of the token
            uint256 lpPrice = getTokenPrice(
                lp,
                factory,
                mainPriceGetter,
                wrappedNative,
                stableUsdTokens,
                nativeLiquidityThreshold
            );
            return lpPrice;
        }
    }

    // ========== NATIVE PRICE ==========

    function getNativePrice(
        address factory,
        IPriceGetter mainPriceGetter,
        IPriceGetter.TokenAndDecimals memory wrappedNative,
        IPriceGetter.TokenAndDecimals[] memory stableUsdTokens,
        uint256 nativeLiquidityThreshold
    ) public view returns (uint256 price) {
        ISolidlyFactory factorySolidly = ISolidlyFactory(factory);
        uint256 wrappedNativeTotal;

        /// @dev This method calculates the price of wrappedNative by comparing multiple stable pools and weighting by their oracle price
        uint256 usdStableTotal = 0;
        for (uint256 i = 0; i < stableUsdTokens.length; i++) {
            IPriceGetter.TokenAndDecimals memory stableUsdToken = stableUsdTokens[i];
            (
                uint256 wrappedNativeReserve,
                uint256 stableUsdReserve
            ) = _getNormalizedReservesFromFactorySolidly_Decimals(
                    factorySolidly,
                    wrappedNative.tokenAddress,
                    stableUsdToken.tokenAddress,
                    wrappedNative.decimals,
                    stableUsdToken.decimals
                );
            uint256 stableUsdPrice = mainPriceGetter.getOraclePriceNormalized(stableUsdToken.tokenAddress);
            if (stableUsdPrice > 0) {
                /// @dev Weighting the USD side of the pair by the price of the USD stable token if it exists.
                usdStableTotal += (stableUsdReserve * stableUsdPrice) / 1e18;
            } else {
                usdStableTotal += stableUsdReserve;
            }
            wrappedNativeTotal += wrappedNativeReserve;
        }

        price = (usdStableTotal * 1e18) / wrappedNativeTotal;
    }

    // ========== INTERNAL FUNCTIONS ==========

    /**
     * @dev Get normalized reserves for a given token pair from the ApeSwap Factory contract, specifying decimals.
     * @param factorySolidly The address of the V2 factory.
     * @param tokenA The address of the first token in the pair.
     * @param tokenB The address of the second token in the pair.
     * @param decimalsA The number of decimals for the first token in the pair.
     * @param decimalsB The number of decimals for the second token in the pair.
     * @return normalizedReserveA The normalized reserve of the first token in the pair.
     * @return normalizedReserveB The normalized reserve of the second token in the pair.
     */
    function _getNormalizedReservesFromFactorySolidly_Decimals(
        ISolidlyFactory factorySolidly,
        address tokenA,
        address tokenB,
        uint8 decimalsA,
        uint8 decimalsB
    ) internal view returns (uint256 normalizedReserveA, uint256 normalizedReserveB) {
        /// @dev Defaulting to stable == false
        try factorySolidly.getPair(tokenA, tokenB, false) returns (address pairAddress) {
            if (pairAddress == address(0)) {
                return (0, 0);
            }
            return _getNormalizedReservesFromPair_Decimals(pairAddress, tokenA, tokenB, decimalsA, decimalsB);
        } catch {}
        try factorySolidly.getPool(tokenA, tokenB, false) returns (address pairAddress) {
            if (pairAddress == address(0)) {
                return (0, 0);
            }
            return _getNormalizedReservesFromPair_Decimals(pairAddress, tokenA, tokenB, decimalsA, decimalsB);
        } catch {}
        revert("No pair found");
    }

    /**
     * @dev This internal function takes in a pair address, two token addresses (tokenA and tokenB), and their respective decimals.
     * It returns the normalized reserves for each token in the pair.
     *
     * This function uses the ISolidlyPair interface to get the current reserves of the given token pair
     * If successful, it returns the normalized reserves for each token in the pair by calling _normalize() on
     * the reserve values. The order of the returned normalized reserve values depends on the lexicographic ordering
     * of tokenA and tokenB.
     *
     * @param pair Address of the liquidity pool contract representing the token pair
     * @param tokenA Address of one of the tokens in the pair. Assumed to be a valid address in the pair to save on gas.
     * @param tokenB Address of the other token in the pair. Assumed to be a valid address in the pair to save on gas.
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
        (bool success, bytes memory returnData) = pair.staticcall(abi.encodeWithSignature("getReserves()"));

        if (success) {
            try this.decodeReservesWithLP(returnData) returns (uint112 reserve0, uint112 reserve1, uint32) {
                if (UtilityLibrary._isSorted(tokenA, tokenB)) {
                    return (
                        UtilityLibrary._normalize(reserve0, decimalsA),
                        UtilityLibrary._normalize(reserve1, decimalsB)
                    );
                } else {
                    return (
                        UtilityLibrary._normalize(reserve1, decimalsA),
                        UtilityLibrary._normalize(reserve0, decimalsB)
                    );
                }
            } catch {
                (success, returnData) = pair.staticcall(abi.encodeWithSignature("getFictiveReserves()"));
                try this.decodeReservesWithoutLP(returnData) returns (uint256 reserve0, uint256 reserve1) {
                    if (UtilityLibrary._isSorted(tokenA, tokenB)) {
                        return (
                            UtilityLibrary._normalize(reserve0, decimalsA),
                            UtilityLibrary._normalize(reserve1, decimalsB)
                        );
                    } else {
                        return (
                            UtilityLibrary._normalize(reserve1, decimalsA),
                            UtilityLibrary._normalize(reserve0, decimalsB)
                        );
                    }
                } catch {
                    return (0, 0);
                }
            }
        } else {
            return (0, 0);
        }
    }

    function decodeReservesWithLP(
        bytes memory data
    ) public pure returns (uint112 reserve0, uint112 reserve1, uint32 lp) {
        return abi.decode(data, (uint112, uint112, uint32));
    }

    function decodeReservesWithoutLP(bytes memory data) public pure returns (uint256 reserve0, uint256 reserve1) {
        return abi.decode(data, (uint256, uint256));
    }
}
