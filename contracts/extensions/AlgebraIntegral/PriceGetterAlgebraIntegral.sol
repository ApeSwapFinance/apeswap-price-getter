// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.16;

import "../IPriceGetterProtocol.sol";
import "../../IPriceGetter.sol";
import "../../lib/UtilityLibrary.sol";
import "./interfaces/IAlgebraPool.sol";
import "./interfaces/IAlgebraFactory.sol";

contract PriceGetterAlgebraV4 is IPriceGetterProtocol {
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

        tempPrice = _getRelativePriceLP(factoryAlgebra, token, params.wrappedNative.tokenAddress);
        if (tempPrice > 0) {
            address pair = factoryAlgebra.poolByPair(token, params.wrappedNative.tokenAddress);
            uint256 balance = IERC20(token).balanceOf(pair);
            uint256 wNativeBalance = IERC20(params.wrappedNative.tokenAddress).balanceOf(pair);
            if (wNativeBalance > params.nativeLiquidityThreshold) {
                totalPrice += ((tempPrice * nativePrice) / 1e18) * balance;
                totalBalance += balance;
            }
        }

        for (uint256 i = 0; i < params.stableUsdTokens.length; i++) {
            address stableUsdTokenAddress = params.stableUsdTokens[i].tokenAddress;
            tempPrice = _getRelativePriceLP(factoryAlgebra, token, stableUsdTokenAddress);
            if (tempPrice > 0) {
                address pair = factoryAlgebra.poolByPair(token, stableUsdTokenAddress);
                uint256 balance = IERC20(token).balanceOf(pair);
                uint256 balanceStable = IERC20(stableUsdTokenAddress).balanceOf(pair);
                if (balanceStable >= 10 * (10 ** IERC20(stableUsdTokenAddress).decimals())) {
                    uint256 stableUsdPrice = params.mainPriceGetter.getOraclePriceNormalized(stableUsdTokenAddress);
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
        IAlgebraFactory factoryAlgebra = IAlgebraFactory(factory);
        address token0 = IAlgebraPool(lp).token0();
        address token1 = IAlgebraPool(lp).token1();
        return _getRelativePriceLP(factoryAlgebra, token0, token1);
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
            price = _getRelativePriceLP(factoryAlgebra, params.wrappedNative.tokenAddress, stableUsdToken);
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

    function _getRelativePriceLP(
        IAlgebraFactory factoryAlgebra,
        address token0,
        address token1
    ) internal view returns (uint256 price) {
        address tokenPegPair = IAlgebraFactory(factoryAlgebra).poolByPair(token0, token1);
        if (tokenPegPair == address(0)) return 0;

        uint256 sqrtPriceX96;
        (sqrtPriceX96, , , , , ) = IAlgebraPool(tokenPegPair).globalState();

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
