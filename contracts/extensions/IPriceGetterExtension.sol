// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.16;

import "../IPriceGetter.sol";

interface IPriceGetterExtension {
    /**
     * @dev Returns the price of a token.
     * @param token The address of the token to get the price for.
     * @return price The current price of the token.
     */
    function getTokenPrice(
        address token,
        address factory,
        IPriceGetter mainPriceGetter,
        IPriceGetter.TokenAndDecimals memory wNative,
        IPriceGetter.TokenAndDecimals[] memory stableUsdTokens,
        uint256 nativeLiquidityThreshold
    ) external view returns (uint256 price);

    /**
     * @dev Returns the price of an LP token.
     * @param lp The address of the LP token to get the price for.
     * @return price The current price of the LP token.
     */
    function getLPPrice(
        address lp,
        address factory,
        IPriceGetter mainPriceGetter,
        IPriceGetter.TokenAndDecimals memory wNative,
        IPriceGetter.TokenAndDecimals[] memory stableUsdTokens,
        uint256 nativeLiquidityThreshold
    ) external view returns (uint256 price);

    /**
     * @dev Returns the current price of the native token in USD.
     * @return nativePrice The current price of the native token in USD.
     */
    function getNativePrice(
        address factory,
        IPriceGetter mainPriceGetter,
        IPriceGetter.TokenAndDecimals memory wNative,
        IPriceGetter.TokenAndDecimals[] memory stableUsdTokens,
        uint256 nativeLiquidityThreshold
    ) external view returns (uint256 nativePrice);
}
