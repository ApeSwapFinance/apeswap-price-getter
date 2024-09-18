// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.16;

import "./IPriceGetterExtension.sol";
import "../IPriceGetter.sol";
import "../lib/UtilityLibrary.sol";
import "../interfaces/IXfaiFactory.sol";
import "../interfaces/IXfaiPool.sol";

//THIS CONTRACT IS NOT CORRECT
contract PriceGetterXfai is IPriceGetterExtension {
    // ========== Get Token Prices ==========

    mapping(uint256 => address) public XFIT;

    constructor() {
        XFIT[59144] = 0x8C56017B172226fE024dEa197748FC1eaccC82B1;
    }

    function getTokenPrice(
        address token,
        address factory,
        IPriceGetter mainPriceGetter,
        IPriceGetter.TokenAndDecimals memory wrappedNative,
        IPriceGetter.TokenAndDecimals[] memory stableUsdTokens,
        uint256 nativeLiquidityThreshold
    ) public view override returns (uint256 price) {
        IXfaiFactory factoryXFAI = IXfaiFactory(factory);
        uint256 nativePrice = mainPriceGetter.getNativePrice(IPriceGetter.Protocol.XFAI, address(factoryXFAI));
        if (token == wrappedNative.tokenAddress) {
            return nativePrice;
        }

        uint256 tempPrice;
        uint256 totalPrice;
        uint256 totalBalance;

        for (uint256 i = 0; i < stableUsdTokens.length; i++) {
            address stableUsdToken = stableUsdTokens[i].tokenAddress;
            tempPrice = _getLPPrice(factoryXFAI, token); //, stableUsdToken);
            if (tempPrice > 0) {
                address pair = factoryXFAI.getPool(token);
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
        IXfaiFactory factoryXFAI = IXfaiFactory(factory);
        address token0 = IXfaiPool(lp).poolToken();
        return _getLPPrice(factoryXFAI, token0);
    }

    // ========== NATIVE PRICE ==========

    function getNativePrice(
        address factory,
        IPriceGetter mainPriceGetter,
        IPriceGetter.TokenAndDecimals memory wrappedNative,
        IPriceGetter.TokenAndDecimals[] memory stableUsdTokens,
        uint256 nativeLiquidityThreshold
    ) public view override returns (uint256 price) {
        IXfaiFactory factoryXFAI = IXfaiFactory(factory);
        uint256 totalPrice;
        uint256 wNativeTotal;

        for (uint256 i = 0; i < stableUsdTokens.length; i++) {
            address stableUsdToken = stableUsdTokens[i].tokenAddress;
            price = _getLPPrice(factoryXFAI, wrappedNative.tokenAddress); //, stableUsdToken);
            uint256 stableUsdPrice = mainPriceGetter.getOraclePriceNormalized(stableUsdToken);
            if (stableUsdPrice > 0) {
                price = (price * stableUsdPrice) / 1e18;
            }
            if (price > 0) {
                address pair = factoryXFAI.getPool(wrappedNative.tokenAddress);
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

    function _getLPPrice(IXfaiFactory factoryXFAI, address token0) internal view returns (uint256 price) {
        address tokenPegPair = factoryXFAI.getPool(token0);
        address token1 = XFIT[block.chainid];

        if (tokenPegPair == address(0)) return 0;

        uint256 reserve0;
        uint256 reserve1;
        (reserve0, reserve1, ) = IXfaiPool(tokenPegPair).getStates();

        uint256 token0Decimals = UtilityLibrary._getTokenDecimals(token0);
        uint256 token1Decimals = UtilityLibrary._getTokenDecimals(token1);

        if (reserve0 == 0 || reserve1 == 0) {
            return 0;
        }

        if (token1 < token0) {
            price = (reserve1 * 10 ** token0Decimals) / reserve0;
        } else {
            price = (reserve0 * 10 ** token1Decimals) / reserve1;
        }
    }
}
