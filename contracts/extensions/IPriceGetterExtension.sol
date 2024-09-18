// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.16;

import "../IPriceGetter.sol";

interface IPriceGetterExtension {
    struct PriceGetterParams {
        IPriceGetter mainPriceGetter;
        IPriceGetter.TokenAndDecimals wrappedNative;
        IPriceGetter.TokenAndDecimals[] stableUsdTokens;
        uint256 nativeLiquidityThreshold;
    }

    /**
     * @dev Returns the price of a token.
     * @param token The address of the token to get the price for.
     * @return price The current price of the token.
     */
    function getTokenPrice(
        address token,
        address factory,
        PriceGetterParams memory params
    ) external view returns (uint256 price);

    /**
     * @dev Returns the price of an LP token.
     * @param lp The address of the LP token to get the price for.
     * @return price The current price of the LP token.
     */
    function getLPPrice(
        address lp,
        address factory,
        PriceGetterParams memory params
    ) external view returns (uint256 price);

    /**
     * @dev Returns the current price of the native token in USD.
     * @return nativePrice The current price of the native token in USD.
     */
    function getNativePrice(
        address factory,
        PriceGetterParams memory params
    ) external view returns (uint256 nativePrice);
}
