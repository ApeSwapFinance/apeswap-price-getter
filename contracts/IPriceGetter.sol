// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.16;

interface IPriceGetter {
    enum Protocol {
        __,
        Both,
        V2,
        V3
    }

    function getLPPriceV2(address lp) external view returns (uint256);

    function getLPPriceV3(
        address token0,
        address token1,
        uint24 fee,
        uint32 secondsAgo
    ) external view returns (uint256);

    function getLPPricesV2(address[] calldata tokens) external view returns (uint256[] memory prices);

    function getLPPricesV3(
        address[] calldata tokens0,
        address[] calldata tokens1,
        uint24[] calldata fees,
        uint24 secondsAgo
    ) external view returns (uint256[] memory prices);

    function getNativePrice(Protocol protocol, uint32 secondsAgo) external view returns (uint256);

    function getPrice(
        address token,
        Protocol protocol,
        uint32 secondsAgo
    ) external view returns (uint256);

    function getPrices(
        address[] calldata tokens,
        Protocol protocol,
        uint32 secondsAgo
    ) external view returns (uint256[] memory prices);
}
