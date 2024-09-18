// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.16;

import "./IPriceGetterExtension.sol";
import "../IPriceGetter.sol";
import "../lib/UtilityLibrary.sol";
import "../interfaces/IAlgebraPool.sol";
import "../interfaces/IAlgebraFactory.sol";

contract PriceGetterAlgebra is IPriceGetterExtension {
    // ========== Get Token Prices ==========

    function getTokenPrice(
        address token,
        address factory,
        PriceGetterParams memory params
    ) public view override returns (uint256 price) {
        IAlgebraFactory factoryAlgebra = IAlgebraFactory(factory);
        uint256 nativePrice = params.mainPriceGetter.getNativePrice(IPriceGetter.Protocol.Algebra, factory);
        if (token == params.wrappedNative.tokenAddress) {
            return nativePrice;
        }

        uint256 tempPrice;
        uint256 totalPrice;
        uint256 totalBalance;

        for (uint256 i = 0; i < params.stableUsdTokens.length; i++) {
            address stableUsdToken = params.stableUsdTokens[i].tokenAddress;
            tempPrice = _getLPPrice(address(factoryAlgebra), token, stableUsdToken);
            if (tempPrice > 0) {
                address pair = factoryAlgebra.poolByPair(token, stableUsdToken);
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

        if (totalBalance == 0) {
            return 0;
        }
        price = totalPrice / totalBalance;
    }

    // ========== LP PRICE ==========

    function getLPPrice(
        address lp,
        address factory,
        PriceGetterParams memory params
    ) public view override returns (uint256 price) {
        return _getLPPrice(factory, lp, params.wrappedNative.tokenAddress);
    }

    // ========== NATIVE PRICE ==========

    function getNativePrice(
        address factory,
        PriceGetterParams memory params
    ) public view override returns (uint256 price) {
        IAlgebraFactory factoryAlgebra = IAlgebraFactory(factory);
        uint256 totalPrice;
        uint256 wNativeTotal;

        for (uint256 i = 0; i < params.stableUsdTokens.length; i++) {
            address stableUsdToken = params.stableUsdTokens[i].tokenAddress;
            price = _getLPPrice(address(factoryAlgebra), params.wrappedNative.tokenAddress, stableUsdToken);
            uint256 stableUsdPrice = params.mainPriceGetter.getOraclePriceNormalized(stableUsdToken);
            if (stableUsdPrice > 0) {
                price = (price * stableUsdPrice) / 1e18;
            }
            if (price > 0) {
                address pair = factoryAlgebra.poolByPair(params.wrappedNative.tokenAddress, stableUsdToken);
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

    function _getLPPrice(address factoryAlgebra, address token0, address token1) internal view returns (uint256 price) {
        address tokenPegPair = IAlgebraFactory(factoryAlgebra).poolByPair(token0, token1);
        if (tokenPegPair == address(0)) return 0;

        uint256 sqrtPriceX96;
        (sqrtPriceX96, , , , , , ) = IAlgebraPool(tokenPegPair).globalState();

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
