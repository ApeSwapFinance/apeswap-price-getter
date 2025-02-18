// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.16;

interface IPriceGetter {
    enum Protocol {
        __,
        ___,
        UniV2,
        UniV3,
        Algebra,
        _Gamma, // outdated
        _Steer, // outdated
        Solidly,
        Xfai,
        Curve,
        AlgebraIntegral
    }

    enum Wrappers {
        Gamma,
        Ichi,
        Steer
    }

    struct TokenAndDecimals {
        address tokenAddress;
        uint8 decimals;
    }

    function getTokenPrice(address token, Protocol protocol, address factory) external view returns (uint256 price);
    function getLPPrice(address lp, Protocol protocol, address factory) external view returns (uint256 price);
    function getWrappedLPPrice(
        address lp,
        Protocol protocol,
        address factory,
        IPriceGetter.Wrappers wrapper
    ) external view returns (uint256 price);
    function getNativePrice(Protocol protocol, address factory) external view returns (uint256 nativePrice);
    function getOraclePriceNormalized(address token) external view returns (uint256 price);
}
