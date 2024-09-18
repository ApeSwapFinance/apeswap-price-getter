// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.16;

import "./IPriceGetter.sol";
import "./chainlink/ChainlinkOracle.sol";
import "./extensions/IPriceGetterExtension.sol";
import "./lib/UtilityLibrary.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
VERSION: 3.0

DISCLAIMER: 
This smart contract is provided for user interface purposes only and is not intended to be used for smart contract logic. 
Any attempt to rely on this code for the execution of a smart contract may result in unexpected behavior, 
errors, or other issues that could lead to financial loss or other damages. 
The user assumes all responsibility and risk for proper usage. 
The developer and associated parties make no warranties and are not liable for any damages incurred.
*/

contract PriceGetter is IPriceGetter, ChainlinkOracle, Initializable, OwnableUpgradeable {
    enum OracleType {
        NONE,
        CHAIN_LINK
    }

    struct OracleInfo {
        OracleType oracleType;
        address oracleAddress;
        uint8 oracleDecimals;
    }

    mapping(Protocol => IPriceGetterExtension) public protocolPriceGetter;
    mapping(address => OracleInfo) public tokenOracles;
    TokenAndDecimals private wrappedNative;
    TokenAndDecimals[] public stableUsdTokens;
    uint256 public nativeLiquidityThreshold;

    /**
     * @dev This contract constructor takes in several parameters which includes the wrapped native token address,
     * an array of addresses for stable USD tokens, an array of addresses for oracle tokens, and an array of addresses
     * for oracles.
     *
     * @param _wNative Address of the wrapped native token
     * @param _nativeLiquidityThreshold The native liquidity threshold
     * @param _stableUsdTokens Array of stable USD token addresses
     * @param _oracleTokens Array of oracle token addresses
     * @param _oracles Array of oracle addresses
     */
    function initialize(
        address _wNative,
        uint256 _nativeLiquidityThreshold,
        address[] calldata _stableUsdTokens,
        address[] calldata _oracleTokens,
        address[] calldata _oracles
    ) public initializer {
        __Ownable_init();
        nativeLiquidityThreshold = _nativeLiquidityThreshold;
        // Check if the lengths of the oracleTokens and oracles arrays match
        require(_oracleTokens.length == _oracles.length, "Oracle length mismatch");

        // Loop through the oracleTokens array and set the oracle address for each oracle token using the _setTokenOracle() internal helper function
        for (uint256 i = 0; i < _oracleTokens.length; i++) {
            /// @dev Assumes OracleType.CHAIN_LINK
            _setTokenOracle(_oracleTokens[i], _oracles[i], OracleType.CHAIN_LINK);
        }

        // Add the stable USD tokens to the stableCoins array using the addStableUsdTokens() internal helper function
        addStableUsdTokens(_stableUsdTokens);

        // Set the wrapped native token (wrappedNative) address
        wrappedNative = TokenAndDecimals(_wNative, UtilityLibrary._getTokenDecimals(_wNative));
    }

    /** SETTERS */

    /**
     * @dev Adds new stable USD tokens to the list of supported stable USD tokens.
     * @param newStableUsdTokens An array of addresses representing the new stable USD tokens to add.
     */
    function addStableUsdTokens(address[] calldata newStableUsdTokens) public onlyOwner {
        for (uint256 i = 0; i < newStableUsdTokens.length; i++) {
            address stableUsdToken = newStableUsdTokens[i];
            bool exists = false;

            for (uint256 j = 0; j < stableUsdTokens.length; j++) {
                if (stableUsdTokens[j].tokenAddress == stableUsdToken) {
                    exists = true;
                    break;
                }
            }

            if (!exists) {
                TokenAndDecimals memory newStableToken = TokenAndDecimals(
                    stableUsdToken,
                    UtilityLibrary._getTokenDecimals(stableUsdToken)
                );
                stableUsdTokens.push(newStableToken);
            }
        }
    }

    /**
     * @dev Removes the stable address.
     * @param tokens An array of token addresses to remove the stable address for.
     */
    function removeStableUsdTokens(address[] calldata tokens) external onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 length = stableUsdTokens.length;
            for (uint256 j = 0; j < length; j++) {
                if (stableUsdTokens[j].tokenAddress == token) {
                    stableUsdTokens[j] = stableUsdTokens[length - 1];
                    stableUsdTokens.pop();
                    break;
                }
            }
        }
    }

    /**
     * @dev Sets the oracle address and type for a specified token.
     * @param token The address of the token to set the oracle for.
     * @param oracleAddress The address of the oracle contract.
     * @param oracleType The type of the oracle (e.g. Chainlink, Uniswap).
     */
    function setTokenOracle(address token, address oracleAddress, OracleType oracleType) public onlyOwner {
        _setTokenOracle(token, oracleAddress, oracleType);
    }

    /**
     * @dev Removes the oracle address for a specified token.
     * @param token The address of the token to set the oracle for.
     */
    function removeTokenOracle(address token) public onlyOwner {
        delete tokenOracles[token];
    }

    /**
     * @dev Sets the oracle address and type for a specified token.
     * @param token The address of the token to set the oracle for.
     * @param oracleAddress The address of the oracle contract.
     * @param oracleType The type of the oracle (e.g. Chainlink, Uniswap).
     */
    function _setTokenOracle(address token, address oracleAddress, OracleType oracleType) internal {
        uint8 oracleDecimals = 18;
        try IERC20(oracleAddress).decimals() returns (uint8 dec) {
            oracleDecimals = dec;
        } catch {}

        tokenOracles[token] = OracleInfo({
            oracleType: oracleType,
            oracleAddress: oracleAddress,
            oracleDecimals: oracleDecimals
        });
    }

    function setNativeLiquidityThreshold(uint256 _nativeLiquidityThreshold) public onlyOwner {
        nativeLiquidityThreshold = _nativeLiquidityThreshold;
    }

    /** GETTERS */

    // ===== Get LP Prices =====

    /**
     * @dev Returns the prices of LP token from a specic protocol an factory.
     * @param token The address of the LP token
     * @param protocol The protocol version to use
     * @param factory The address of the factory used to calculate the price.
     * @return price The current price of LP.
     * @dev Protocol V3 and Algebra not yet supported in here because functions token 2 tokens instead of 1 and for V3 also a fee.
     * Use the dedicated functions for these protocols
     */
    function getLPPrice(address token, Protocol protocol, address factory) public view returns (uint256 price) {
        IPriceGetterExtension extension = getPriceGetterExtension(protocol);
        price = extension.getLPPrice(token, factory, this, wrappedNative, stableUsdTokens, nativeLiquidityThreshold);
    }

    // ===== Get Native Prices =====

    /**
     * @dev Returns the current price of wrappedNative in USD based on the given protocol.
     * @param protocol The protocol version to use
     * @param factory The address of the factory used to calculate the price.
     * @return nativePrice The current price of wrappedNative in USD.
     */
    function getNativePrice(Protocol protocol, address factory) public view returns (uint256 nativePrice) {
        /// @dev Short circuit if oracle price is found
        uint256 oraclePrice = getOraclePriceNormalized(wrappedNative.tokenAddress);
        if (oraclePrice > 0) {
            return oraclePrice;
        }

        IPriceGetterExtension extension = getPriceGetterExtension(protocol);
        nativePrice = extension.getNativePrice(factory, this, wrappedNative, stableUsdTokens, nativeLiquidityThreshold);
    }

    // ===== Get Token Prices =====

    /**
     * @dev Returns the current price of the given token based on the specified protocol and time interval.
     * If protocol is set to 'Both', the price is calculated as a weighted average of the V2 and V3 prices,
     * where the weights are the respective liquidity pools. If protocol is set to 'V2' or 'V3', the price
     * is calculated based on the respective liquidity pool.
     * @param token Address of the token for which the price is requested.
     * @param protocol The liquidity protocol used to calculate the price.
     * @param factory The address of the factory used to calculate the price.
     * @return tokenPrice The price of the token in USD.
     */
    function getTokenPrice(address token, Protocol protocol, address factory) public view returns (uint256 tokenPrice) {
        if (token == wrappedNative.tokenAddress) {
            return getNativePrice(protocol, factory);
        }

        IPriceGetterExtension extension = getPriceGetterExtension(protocol);
        tokenPrice = extension.getTokenPrice(
            token,
            factory,
            this,
            wrappedNative,
            stableUsdTokens,
            nativeLiquidityThreshold
        );
    }

    function getTokenPrices(
        address[] calldata tokens,
        Protocol protocol,
        address factory
    ) public view returns (uint256[] memory tokenPrices) {
        uint256 tokenLength = tokens.length;
        tokenPrices = new uint256[](tokenLength);

        for (uint256 i; i < tokenLength; i++) {
            address token = tokens[i];
            tokenPrices[i] = getTokenPrice(token, protocol, factory);
        }
    }

    /**
     * @dev Retrieves the normalized USD price of a token from its oracle.
     * @param token Address of the token to retrieve the price for.
     * @return price The normalized USD price of the token from its oracle.
     */
    function getOraclePriceNormalized(address token) public view returns (uint256 price) {
        OracleInfo memory oracleInfo = tokenOracles[token];
        if (oracleInfo.oracleType == OracleType.CHAIN_LINK) {
            uint256 tokenUSDPrice = _getChainlinkPriceRaw(oracleInfo.oracleAddress);
            return UtilityLibrary._normalize(tokenUSDPrice, oracleInfo.oracleDecimals);
        }
        /// @dev Additional oracle types can be implemented here.
        // else if (oracleInfo.oracleType == OracleType.<NEW_ORACLE>) { }
        return 0;
    }

    function getPriceGetterExtension(Protocol protocol) public view returns (IPriceGetterExtension extension) {
        extension = protocolPriceGetter[protocol];
        if (address(extension) == address(0)) {
            revert("Invalid extension");
        }
    }

    /** VIEW FUNCTIONS */
}
