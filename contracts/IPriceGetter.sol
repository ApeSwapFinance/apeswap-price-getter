// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.16;

interface IPriceGetter {
    enum Protocol {
        __,
        Both,
        V2,
        V3
    }

    function getLPPriceV2(address lp) external view returns (uint256 price);

    function getLPPricesV2(address[] calldata tokens) external view returns (uint256[] memory prices);

    function getPriceV2(address token) external view returns (uint256 price);

    function getLPPriceV3(address token0, address token1, uint24 fee) external view returns (uint256 price);

    function getLPPricesV3(
        address[] calldata tokens0,
        address[] calldata tokens1,
        uint24[] calldata fees
    ) external view returns (uint256[] memory prices);

    function getPriceV3(address token) external view returns (uint256 price);

    function getNativePrice(Protocol protocol) external view returns (uint256 price);

    function getPrice(address token, Protocol protocol) external view returns (uint256 price);

    function getPrices(address[] calldata tokens, Protocol protocol) external view returns (uint256[] memory prices);
}
