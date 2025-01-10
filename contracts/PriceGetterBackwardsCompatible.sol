// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.16;

import "./PriceGetter.sol";

/**
VERSION: 3.0

DISCLAIMER: 
This smart contract is provided for user interface purposes only and is not intended to be used for smart contract logic. 
Any attempt to rely on this code for the execution of a smart contract may result in unexpected behavior, 
errors, or other issues that could lead to financial loss or other damages. 
The user assumes all responsibility and risk for proper usage. 
The developer and associated parties make no warranties and are not liable for any damages incurred.
*/

contract PriceGetterBackwardsCompatible is PriceGetter {
    // ========== Get Token Prices ==========

    /**
     * @dev Returns the price of a token from a specific factory based on the protocol.
     * @param token The address of the token for which the price is requested.
     * @param protocol The protocol version to use for the price retrieval.
     * @param factoryV2 The address of the V2 factory.
     * @param factoryV3 The address of the V3 factory.
     * @param factoryAlgebra The address of the Algebra factory.
     * @param factorySolidly The address of the Solidly factory.
     * @return price The price of the token in USD.
     */
    function getPriceFromFactory(
        address token,
        Protocol protocol,
        address factoryV2,
        address factoryV3,
        address factoryAlgebra,
        address factorySolidly
    ) public view returns (uint256 price) {
        return _getPriceFromFactory(token, protocol, factoryV2, factoryV3, factoryAlgebra, factorySolidly, address(0));
    }

    /**
     * @dev Returns the price of a token from a specific factory based on the protocol.
     * @param token The address of the token for which the price is requested.
     * @param protocol The protocol version to use for the price retrieval.
     * @param factoryV2 The address of the V2 factory.
     * @param factoryV3 The address of the V3 factory.
     * @param factoryAlgebra The address of the Algebra factory.
     * @param factorySolidly The address of the Solidly factory.
     * @param factoryXFAI The address of the XFAI factory.
     * @return price The price of the token in USD.
     */
    function getPriceFromFactory(
        address token,
        Protocol protocol,
        address factoryV2,
        address factoryV3,
        address factoryAlgebra,
        address factorySolidly,
        address factoryXFAI
    ) public view returns (uint256 price) {
        return _getPriceFromFactory(token, protocol, factoryV2, factoryV3, factoryAlgebra, factorySolidly, factoryXFAI);
    }

    function _getPriceFromFactory(
        address token,
        Protocol protocol,
        address factoryV2,
        address factoryV3,
        address factoryAlgebra,
        address factorySolidly,
        address factoryXFAI
    ) internal view returns (uint256 price) {
        if (protocol == Protocol.___) {
            uint256 priceV2 = getTokenPrice(token, Protocol.UniV2, factoryV2);
            uint256 priceV3 = getTokenPrice(token, Protocol.UniV3, factoryV3);
            return (priceV2 + priceV3) / 2;
        } else if (protocol == Protocol.UniV2) {
            return getTokenPrice(token, protocol, factoryV2);
        } else if (protocol == Protocol.UniV3) {
            return getTokenPrice(token, protocol, factoryV3);
        } else if (protocol == Protocol.Algebra) {
            return getTokenPrice(token, protocol, factoryAlgebra);
        } else if (protocol == Protocol.Solidly) {
            return getTokenPrice(token, protocol, factorySolidly);
        } else if (protocol == Protocol.Xfai) {
            return getTokenPrice(token, protocol, factoryXFAI);
        } else if (protocol == Protocol.Curve) {
            return getTokenPrice(token, protocol, factoryV2);
        } else {
            revert("Invalid");
        }
    }

    // ========== Get LP Prices ==========

    /**
     * @dev Returns the price of an LP token from a specific protocol and factory.
     * @param lp The address of the LP token for which the price is requested.
     * @param protocol The protocol version to use.
     * @param factoryV2 The address of the V2 factory.
     * @param factoryV3 The address of the V3 factory.
     * @param factoryAlgebra The address of the Algebra factory.
     * @param factorySolidly The address of the Solidly factory.
     * @return lpPrice The current price of the LP token.
     */
    function getLPPriceFromFactory(
        address lp,
        Protocol protocol,
        address factoryV2,
        address factoryV3,
        address factoryAlgebra,
        address factorySolidly
    ) public view returns (uint256 lpPrice) {
        return _getLPPriceFromFactory(lp, protocol, factoryV2, factoryV3, factoryAlgebra, factorySolidly, address(0));
    }

    /**
     * @dev Returns the price of an LP token from a specific protocol and factory.
     * @param lp The address of the LP token for which the price is requested.
     * @param protocol The protocol version to use.
     * @param factoryV2 The address of the V2 factory.
     * @param factoryV3 The address of the V3 factory.
     * @param factoryAlgebra The address of the Algebra factory.
     * @param factorySolidly The address of the Solidly factory.
     * @param factoryXFAI The address of the XFAI factory.
     * @return lpPrice The current price of the LP token.
     */
    function getLPPriceFromFactory(
        address lp,
        Protocol protocol,
        address factoryV2,
        address factoryV3,
        address factoryAlgebra,
        address factorySolidly,
        address factoryXFAI
    ) public view returns (uint256 lpPrice) {
        return _getLPPriceFromFactory(lp, protocol, factoryV2, factoryV3, factoryAlgebra, factorySolidly, factoryXFAI);
    }

    function _getLPPriceFromFactory(
        address lp,
        Protocol protocol,
        address factoryV2,
        address factoryV3,
        address factoryAlgebra,
        address factorySolidly,
        address factoryXFAI
    ) internal view returns (uint256 lpPrice) {
        if (protocol == Protocol.___) {
            revert("LP can't be both");
        } else if (protocol == Protocol.UniV2) {
            return getLPPrice(lp, protocol, factoryV2);
        } else if (protocol == Protocol.UniV3) {
            return getLPPrice(lp, protocol, factoryV3);
        } else if (protocol == Protocol.Algebra) {
            return getLPPrice(lp, protocol, factoryAlgebra);
        } else if (protocol == Protocol.Solidly) {
            return getLPPrice(lp, protocol, factorySolidly);
        } else if (protocol == Protocol.Xfai) {
            return getLPPrice(lp, protocol, factoryXFAI);
        } else if (protocol == Protocol.Curve) {
            return getLPPrice(lp, protocol, factoryV2);
        } else if (protocol == Protocol._Gamma) {
            //This does not make sense, it's just for backwards compatibility. Gamma was used for all Algebra wrappers
            return getWrappedLPPrice(lp, Protocol.Algebra, factoryAlgebra, Wrappers.Gamma);
        } else if (protocol == Protocol._Steer) {
            //This does not make sense, it's just for backwards compatibility. Steer was used for all UniV3 wrappers
            return getWrappedLPPrice(lp, Protocol.UniV3, factoryV3, Wrappers.Gamma);
        } else if (protocol == Protocol.Curve) {
            return getLPPrice(lp, protocol, factoryV2);
        } else {
            revert("Invalid");
        }
    }

    // ========== Get Native Prices ==========

    /**
     * @dev Returns the current price of wNative in USD based on the given protocol and time delta.
     * @param protocol The protocol version to use.
     * @param factoryV2 The address of the V2 factory.
     * @param factoryV3 The address of the V3 factory.
     * @param factoryAlgebra The address of the Algebra factory.
     * @param factorySolidly The address of the Solidly factory.
     * @return nativePrice The current price of wNative in USD.
     */
    function getNativePriceFromFactory(
        Protocol protocol,
        address factoryV2,
        address factoryV3,
        address factoryAlgebra,
        address factorySolidly
    ) public view returns (uint256 nativePrice) {
        return _getNativePriceFromFactory(protocol, factoryV2, factoryV3, factoryAlgebra, factorySolidly, address(0));
    }

    /**
     * @dev Returns the current price of wNative in USD based on the given protocol and time delta.
     * This function is an extension of the original `getNativePriceFromFactory` to include support for XFAI protocol.
     * @param protocol The protocol version to use.
     * @param factoryV2 The address of the V2 factory.
     * @param factoryV3 The address of the V3 factory.
     * @param factoryAlgebra The address of the Algebra factory.
     * @param factorySolidly The address of the Solidly factory.
     * @param factoryXFAI The address of the XFAI factory.
     * @return nativePrice The current price of wNative in USD.
     */
    function getNativePriceFromFactory(
        Protocol protocol,
        address factoryV2,
        address factoryV3,
        address factoryAlgebra,
        address factorySolidly,
        address factoryXFAI
    ) public view returns (uint256 nativePrice) {
        return _getNativePriceFromFactory(protocol, factoryV2, factoryV3, factoryAlgebra, factorySolidly, factoryXFAI);
    }

    function _getNativePriceFromFactory(
        Protocol protocol,
        address factoryV2,
        address factoryV3,
        address factoryAlgebra,
        address factorySolidly,
        address factoryXFAI
    ) internal view returns (uint256 nativePrice) {
        if (protocol == Protocol.UniV2) {
            return getNativePrice(protocol, factoryV2);
        } else if (protocol == Protocol.UniV3) {
            return getNativePrice(protocol, factoryV3);
        } else if (protocol == Protocol.Algebra) {
            return getNativePrice(protocol, factoryAlgebra);
        } else if (protocol == Protocol.Solidly) {
            return getNativePrice(protocol, factorySolidly);
        } else if (protocol == Protocol.Xfai) {
            return getNativePrice(protocol, factoryXFAI);
        } else if (protocol == Protocol.Curve) {
            return getNativePrice(protocol, factoryV2);
        } else {
            revert("Invalid");
        }
    }
}
