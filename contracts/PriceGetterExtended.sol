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

}
