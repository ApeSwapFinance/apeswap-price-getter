// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.16;

import "../token-lib/IERC20.sol";

library UtilityLibrary {
    function _isSorted(address tokenA, address tokenB) internal pure returns (bool isSorted) {
        //  (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        isSorted = tokenA < tokenB ? true : false;
    }

    function _getTokenDecimals(address token) internal view returns (uint8 decimals) {
        try IERC20(token).decimals() returns (uint8 dec) {
            decimals = dec;
        } catch {
            decimals = 18;
        }
    }

    /// @notice Normalize the amount of a token to wei or 1e18
    function _normalizeToken(uint256 amount, address token) internal view returns (uint256) {
        return _normalize(amount, _getTokenDecimals(token));
    }

    /// @notice Normalize the amount of a token to wei or 1e18
    function _normalizeToken112(uint112 amount, address token) internal view returns (uint112) {
        return _normalize112(amount, _getTokenDecimals(token));
    }

    /// @notice Normalize the amount passed to wei or 1e18 decimals
    function _normalize(uint256 amount, uint8 decimals) internal pure returns (uint256) {
        if (decimals == 18) return amount;
        return (amount * (10 ** 18)) / (10 ** decimals);
    }

    /// @notice Normalize the amount passed to wei or 1e18 decimals
    function _normalize112(uint112 amount, uint8 decimals) internal pure returns (uint112) {
        if (decimals == 18) {
            return amount;
        } else if (decimals > 18) {
            return uint112(amount / (10 ** (decimals - 18)));
        } else {
            return uint112(amount * (10 ** (18 - decimals)));
        }
    }
}
