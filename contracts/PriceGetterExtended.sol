// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.16;

import "./IPriceGetterV1.sol";
import "./PriceGetterV2.sol";

/**
DISCLAIMER:
This smart contract is provided for user interface purposes only and is not intended to be used for smart contract logic. 
Any attempt to rely on this code for the execution of a smart contract may result in unexpected behavior, 
errors, or other issues that could lead to financial loss or other damages. 
The user assumes all responsibility and risk for proper usage. 
The developer and associated parties make no warranties and are not liable for any damages incurred.
*/

contract PriceGetterExtended is IPriceGetterV1, PriceGetterV2 {
    /**
     * @dev This contract constructor takes in several parameters which includes the wrapped native token address,
     * an array of addresses for stable USD tokens, an array of addresses for oracle tokens, and an array of addresses
     * for oracles.
     *
     * @param _wNative Address of the wrapped native token
     * @param _defaultFactoryV2 Address of factoryV2
     * @param _defaultFactoryV3 Address of factoryV3
     * @param _stableUsdTokens Array of stable USD token addresses
     * @param _oracleTokens Array of oracle token addresses
     * @param _oracles Array of oracle addresses
     */
    constructor(
        address _wNative,
        IApeFactory _defaultFactoryV2,
        IUniswapV3Factory _defaultFactoryV3,
        address[] memory _stableUsdTokens,
        address[] memory _oracleTokens,
        address[] memory _oracles
    ) PriceGetterV2(_wNative, _defaultFactoryV2, _defaultFactoryV3, _stableUsdTokens, _oracleTokens, _oracles) {}

    // TODO: Implement IPriceGetterV1
}
