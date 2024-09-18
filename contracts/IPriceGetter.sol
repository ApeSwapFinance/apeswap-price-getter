// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.16;

interface IPriceGetter {
    enum Protocol {
        __,
        ___,
        V2,
        V3,
        Algebra,
        Gamma,
        Steer,
        Solidly,
        XFAI
    }

    struct TokenAndDecimals {
        address tokenAddress;
        uint8 decimals;
    }

    function getLPPrice(address lp, Protocol protocol, address factory) external view returns (uint256 price);
    function getTokenPrice(address token, Protocol protocol, address factory) external view returns (uint256 price);
    function getNativePrice(Protocol protocol, address factory) external view returns (uint256 nativePrice);
    function getOraclePriceNormalized(address token) external view returns (uint256 price);
}
