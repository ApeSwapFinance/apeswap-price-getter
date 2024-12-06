// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.16;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "./interfaces/IUniswapV3PoolStateSlot0.sol";

import "../IPriceGetterProtocol.sol";
import "../../IPriceGetter.sol";
import "../../lib/UtilityLibrary.sol";

contract PriceGetterUniV3 is IPriceGetterProtocol {
    // ========== Get Token Prices ==========

    function getTokenPrice(
        address token,
        address factory,
        PriceGetterParams memory params
    ) public view override returns (uint256 price) {
        IUniswapV3Factory factoryUniV3 = IUniswapV3Factory(factory);
        uint256 nativePrice = params.mainPriceGetter.getNativePrice(IPriceGetter.Protocol.UniV3, address(factoryUniV3));
        if (token == params.wrappedNative.tokenAddress) {
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
            tempPrice = _getRelativePriceLP(factoryUniV3, token, params.wrappedNative.tokenAddress, fee);
            if (tempPrice > 0) {
                address pair = factoryUniV3.getPool(token, params.wrappedNative.tokenAddress, fee);
                uint256 balance = IERC20(token).balanceOf(pair);
                uint256 wNativeBalance = IERC20(params.wrappedNative.tokenAddress).balanceOf(pair);
                if (wNativeBalance > params.nativeLiquidityThreshold) {
                    totalPrice += ((tempPrice * nativePrice) / 1e18) * balance;
                    totalBalance += balance;
                }
            }

            (uint256 addTotalPrice, uint256 addTotalBalance) = _calculateStableUsdPrices(
                factoryUniV3,
                token,
                fee,
                params
            );
            totalPrice += addTotalPrice;
            totalBalance += addTotalBalance;
        }

        if (totalBalance == 0) {
            return 0;
        }
        price = totalPrice / totalBalance;
    }

    function _calculateStableUsdPrices(
        IUniswapV3Factory factoryUniV3,
        address token,
        uint24 fee,
        PriceGetterParams memory params
    ) internal view returns (uint256 totalPrice, uint256 totalBalance) {
        for (uint256 i = 0; i < params.stableUsdTokens.length; i++) {
            address stableUsdToken = params.stableUsdTokens[i].tokenAddress;
            uint256 tempPrice = _getRelativePriceLP(factoryUniV3, token, stableUsdToken, fee);
            if (tempPrice > 0) {
                address pair = factoryUniV3.getPool(token, stableUsdToken, fee);
                uint256 balance = IERC20(token).balanceOf(pair);
                uint256 balanceStable = IERC20(stableUsdToken).balanceOf(pair);
                if (balanceStable > 10 * (10 ** IERC20(stableUsdToken).decimals())) {
                    uint256 stableUsdPrice = params.mainPriceGetter.getOraclePriceNormalized(stableUsdToken);
                    if (stableUsdPrice > 0) {
                        tempPrice = (tempPrice * stableUsdPrice) / 1e18;
                    }
                    totalPrice += tempPrice * balance;
                    totalBalance += balance;
                }
            }
        }
    }

    // ========== LP PRICE ==========

    function getLPPrice(
        address lp,
        address factory,
        PriceGetterParams memory params
    ) public view override returns (uint256 price) {
        IUniswapV3Factory factoryUniV3 = IUniswapV3Factory(factory);
        IUniswapV3Pool pool = IUniswapV3Pool(lp);
        address token0 = pool.token0();
        address token1 = pool.token1();
        uint24 fee = pool.fee();
        return _getRelativePriceLP(factoryUniV3, token0, token1, fee);
    }

    // ========== NATIVE PRICE ==========

    function getNativePrice(
        address factory,
        PriceGetterParams memory params
    ) public view override returns (uint256 price) {
        IUniswapV3Factory factoryUniV3 = IUniswapV3Factory(factory);
        uint256 totalPrice;
        uint256 wNativeTotal;

        for (uint256 i = 0; i < params.stableUsdTokens.length; i++) {
            address stableUsdToken = params.stableUsdTokens[i].tokenAddress;
            price = _getRelativePriceLP(factoryUniV3, params.wrappedNative.tokenAddress, stableUsdToken, 3000);
            uint256 stableUsdPrice = params.mainPriceGetter.getOraclePriceNormalized(stableUsdToken);
            if (stableUsdPrice > 0) {
                price = (price * stableUsdPrice) / 1e18;
            }
            if (price > 0) {
                address pair = factoryUniV3.getPool(params.wrappedNative.tokenAddress, stableUsdToken, 3000);
                uint256 balance = IERC20(params.wrappedNative.tokenAddress).balanceOf(pair);
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

    function _getRelativePriceLP(
        IUniswapV3Factory factoryUniV3,
        address token0,
        address token1,
        uint24 fee
    ) internal view returns (uint256 price) {
        address tokenPegPair = factoryUniV3.getPool(token0, token1, fee);
        if (tokenPegPair == address(0)) return 0;

        uint256 sqrtPriceX96;
        (sqrtPriceX96, , , , , , ) = IUniswapV3PoolStateSlot0(tokenPegPair).slot0();

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
