// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.16;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";

import "./IPriceGetterExtension.sol";
import "../IPriceGetter.sol";
import "../lib/UtilityLibrary.sol";

contract PriceGetterUniV3 is IPriceGetterExtension {
    // ========== Get Token Prices ==========

    function getTokenPrice(
        address token,
        address factory,
        IPriceGetter mainPriceGetter,
        IPriceGetter.TokenAndDecimals memory wrappedNative,
        IPriceGetter.TokenAndDecimals[] memory stableUsdTokens,
        uint256 nativeLiquidityThreshold
    ) public view override returns (uint256 price) {
        IUniswapV3Factory factoryUniV3 = IUniswapV3Factory(factory);
        uint256 nativePrice = mainPriceGetter.getNativePrice(IPriceGetter.Protocol.V3, address(factoryUniV3));
        if (token == wrappedNative.tokenAddress) {
            return nativePrice;
        }

        uint256 tempPrice;
        uint256 totalPrice;
        uint256 totalBalance;
        uint24[] memory fees = new uint24[](5);
        fees[0] = 100;
        fees[1] = 500;
        fees[2] = 2500;
        fees[3] = 3000;
        fees[4] = 10000;

        for (uint24 feeIndex = 0; feeIndex < 5; feeIndex++) {
            uint24 fee = fees[feeIndex];
            tempPrice = _getLPPrice(factoryUniV3, token, wrappedNative.tokenAddress, fee);
            if (tempPrice > 0) {
                address pair = factoryUniV3.getPool(token, wrappedNative.tokenAddress, fee);
                uint256 balance = IERC20(token).balanceOf(pair);
                uint256 wNativeBalance = IERC20(wrappedNative.tokenAddress).balanceOf(pair);
                if (wNativeBalance > nativeLiquidityThreshold) {
                    totalPrice += ((tempPrice * nativePrice) / 1e18) * balance;
                    totalBalance += balance;
                }
            }

            for (uint256 i = 0; i < stableUsdTokens.length; i++) {
                address stableUsdToken = stableUsdTokens[i].tokenAddress;
                tempPrice = _getLPPrice(factoryUniV3, token, stableUsdToken, fee);
                if (tempPrice > 0) {
                    address pair = factoryUniV3.getPool(token, stableUsdToken, fee);
                    uint256 balance = IERC20(token).balanceOf(pair);
                    uint256 balanceStable = IERC20(stableUsdToken).balanceOf(pair);
                    if (balanceStable > 10 * (10 ** IERC20(stableUsdToken).decimals())) {
                        uint256 stableUsdPrice = mainPriceGetter.getOraclePriceNormalized(stableUsdToken);
                        if (stableUsdPrice > 0) {
                            tempPrice = (tempPrice * stableUsdPrice) / 1e18;
                        }
                        totalPrice += tempPrice * balance;
                        totalBalance += balance;
                    }
                }
            }
        }

        if (totalBalance == 0) {
            return 0;
        }
        price = totalPrice / totalBalance;
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
        IUniswapV3Factory factoryUniV3 = IUniswapV3Factory(factory);
        IUniswapV3Pool pool = IUniswapV3Pool(lp);
        address token0 = pool.token0();
        address token1 = pool.token1();
        uint24 fee = pool.fee();
        return _getLPPrice(factoryUniV3, token0, token1, fee);
    }

    // ========== NATIVE PRICE ==========

    function getNativePrice(
        address factory,
        IPriceGetter mainPriceGetter,
        IPriceGetter.TokenAndDecimals memory wrappedNative,
        IPriceGetter.TokenAndDecimals[] memory stableUsdTokens,
        uint256 nativeLiquidityThreshold
    ) public view override returns (uint256 price) {
        IUniswapV3Factory factoryUniV3 = IUniswapV3Factory(factory);
        uint256 totalPrice;
        uint256 wNativeTotal;

        for (uint256 i = 0; i < stableUsdTokens.length; i++) {
            address stableUsdToken = stableUsdTokens[i].tokenAddress;
            price = _getLPPrice(factoryUniV3, wrappedNative.tokenAddress, stableUsdToken, 3000);
            uint256 stableUsdPrice = mainPriceGetter.getOraclePriceNormalized(stableUsdToken);
            if (stableUsdPrice > 0) {
                price = (price * stableUsdPrice) / 1e18;
            }
            if (price > 0) {
                address pair = factoryUniV3.getPool(wrappedNative.tokenAddress, stableUsdToken, 3000);
                uint256 balance = IERC20(wrappedNative.tokenAddress).balanceOf(pair);
                totalPrice += price * balance;
                wNativeTotal += balance;
            }
        }

        if (wNativeTotal == 0) {
            return 0;
        }
        price = totalPrice / wNativeTotal;
    }

    // ========== INTERNAL FUNCTIONS ==========

    function _getLPPrice(
        IUniswapV3Factory factoryUniV3,
        address token0,
        address token1,
        uint24 fee
    ) internal view returns (uint256 price) {
        address tokenPegPair = factoryUniV3.getPool(token0, token1, fee);
        if (tokenPegPair == address(0)) return 0;

        uint256 sqrtPriceX96;
        (sqrtPriceX96, , , , , , ) = IUniswapV3Pool(tokenPegPair).slot0();

        uint256 token0Decimals = UtilityLibrary._getTokenDecimals(token0);
        uint256 token1Decimals = UtilityLibrary._getTokenDecimals(token1);

        if (sqrtPriceX96 == 0) {
            return 0;
        }

        uint256 decimalCorrection = 0;
        if (sqrtPriceX96 >= 340282366920938463463374607431768211455) {
            sqrtPriceX96 = sqrtPriceX96 / 1e3;
            decimalCorrection = 6;
        }
        if (sqrtPriceX96 >= 340282366920938463463374607431768211455) {
            return 0;
        }

        if (token1 < token0) {
            price =
                (2 ** 192) /
                ((sqrtPriceX96) ** 2 / uint256(10 ** (token0Decimals + 18 - token1Decimals - decimalCorrection)));
        } else {
            price =
                ((sqrtPriceX96) ** 2) /
                ((2 ** 192) / uint256(10 ** (token0Decimals + 18 - token1Decimals - decimalCorrection)));
        }
    }
}
