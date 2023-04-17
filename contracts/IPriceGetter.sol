// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.16;

interface IPriceGetter {
    // FIXME: Remove/Update interface as needed
    // function FACTORY() external view returns (address);

    function getLPPrice(address token, address factory) external view returns (uint256);

    function getLPPrices(address[] calldata tokens, address factory) external view returns (uint256[] memory prices);

    function getNativePrice(address factory) external view returns (uint256);

    function getPrice(address token, address factory) external view returns (uint256);

    function getPrices(address[] calldata tokens, address factory) external view returns (uint256[] memory prices);

    // function getRawPrice(address token) external view returns (uint256);

    // function getRawPrices(address[] calldata tokens) external view returns (uint256[] memory prices);
}
