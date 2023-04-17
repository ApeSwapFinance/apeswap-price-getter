// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.16;

import "./token-lib/IERC20.sol";
import "./swap-v2-lib/IApePair.sol";
import "./swap-v2-lib/IApeFactory.sol";
import "./chainlink/ChainlinkOracle.sol";
import "./IPriceGetter.sol";

// TODO: Disclaimer, this is for UI purposes only, cannot be used for smart contract logic

contract PriceGetter is IPriceGetter, ChainlinkOracle {
    /*
    // NOTE: 
    Gas is actually an important consideration for this contract because it limits how many of these calls can be batched together in a single multicall read.
    1. _getNormalizedReservesFromFactory_Decimals: The purpose of these functions are to be able to pass in cached decimals to avoid needing to make an extra calls to the token contracts 

    TODO TASKS
    - [ ] Implement base features of IPriceGetter with single router (may be able to move away from the interface a bit)
    - [x] Implement Chainlink price feed
    - [ ] Extend to include dynamic router
    - [ ] Ordering of functions, styling, comments, etc
    - [ ] Fork testing?
    */
    enum OracleType {
        NONE,
        CHAIN_LINK
    }

    struct OracleInfo {
        OracleType oracleType;
        address oracleAddress;
        uint8 oracleDecimals;
    }

    struct LocalVars {
        uint256 tokenTotal;
        uint256 usdStableTotal;
        uint256 wNativeReserve;
        uint256 wNativeTotal;
        uint256 tokenReserve;
        uint256 stableUsdReserve;
    }

    // TODO: Possibly use an enumerable set
    mapping(address => OracleInfo) public tokenOracles;
    address public wNative;
    address[] public stableUsdTokens;
    mapping(address => uint8) public stableUsdTokenDecimals;

    /**
     * @dev This contract constructor takes in several parameters which includes the wrapped native token address,
     * an array of addresses for stable USD tokens, an array of addresses for oracle tokens, and an array of addresses
     * for oracles.
     *
     * @param _wNative Address of the wrapped native token
     * @param _stableUsdTokens Array of stable USD token addresses
     * @param _oracleTokens Array of oracle token addresses
     * @param _oracles Array of oracle addresses
     */
    constructor(
        address _wNative,
        address[] memory _stableUsdTokens,
        address[] memory _oracleTokens,
        address[] memory _oracles
    ) {
        // Check if the lengths of the oracleTokens and oracles arrays match
        require(_oracleTokens.length == _oracles.length, "Oracles length mismatch");

        // Loop through the oracleTokens array and set the oracle address for each oracle token using the _setTokenOracle() internal helper function
        for (uint256 i = 0; i < _oracleTokens.length; i++) {
            /// @dev Assumes OracleType.CHAIN_LINK
            _setTokenOracle(_oracleTokens[i], _oracles[i], OracleType.CHAIN_LINK);
        }

        // Add the stable USD tokens to the stableCoins array using the _addStableUsdTokens() internal helper function
        _addStableUsdTokens(_stableUsdTokens);

        // Set the wrapped native token (wNative) address
        wNative = _wNative;
    }

    /** SETTERS */

    /// @dev Used as a single setter for stable tokens to be able to cache their decimals and reduce future calls.
    function _addStableUsdTokens(address[] memory newStableUsdTokens) internal {
        for (uint256 i = 0; i < newStableUsdTokens.length; i++) {
            address stableUsdToken = newStableUsdTokens[i];
            stableUsdTokens.push(newStableUsdTokens[i]);
            require(stableUsdTokenDecimals[stableUsdToken] == 0, "PriceGetter: Stable token already added");
            stableUsdTokenDecimals[stableUsdToken] = _getTokenDecimals(stableUsdToken);
        }
    }

    function _setTokenOracle(
        address token,
        address oracleAddress,
        OracleType oracleType
    ) internal {
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

    /** GETTERS */

    function getLPPrice(address lp, address factory) public view override returns (uint256) {
        //if not a LP, handle as a standard token
        try IApePair(lp).getReserves() returns (uint112 reserve0, uint112 reserve1, uint32) {
            address token0 = IApePair(lp).token0();
            address token1 = IApePair(lp).token1();
            uint256 totalSupply = IApePair(lp).totalSupply();

            //price0*reserve0+price1*reserve1

            uint256 totalValue = getPrice(token0, factory) * reserve0 + getPrice(token1, factory) * reserve1;

            return totalValue / totalSupply;
        } catch {
            return getPrice(lp, factory);
        }
    }

    function getLPPrices(address[] calldata tokens, address factory)
        external
        view
        override
        returns (uint256[] memory prices)
    {
        prices = new uint256[](tokens.length);
        for (uint256 i; i < prices.length; i++) {
            address token = tokens[i];
            prices[i] = getLPPrice(token, factory);
        }
    }

    function getNativePrice(address factory) external view override returns (uint256) {
        return _getNativePrice(factory);
    }

    function getPrice(address token, address factory) public view override returns (uint256) {
        LocalVars memory vars;

        (vars.tokenReserve, vars.wNativeReserve) = _getNormalizedReservesFromFactory_Decimals(
            factory,
            token,
            wNative,
            _getTokenDecimals(token),
            _getTokenDecimals(wNative)
        );
        vars.wNativeTotal = (vars.wNativeReserve * _getNativePrice(factory)) / 1e18;
        vars.tokenTotal += vars.tokenReserve;

        for (uint256 i = 0; i < stableUsdTokens.length; i++) {
            address stableUsdToken = stableUsdTokens[i];
            (vars.tokenReserve, vars.stableUsdReserve) = _getNormalizedReservesFromFactory_Decimals(
                factory,
                token,
                stableUsdToken,
                _getTokenDecimals(token),
                stableUsdTokenDecimals[stableUsdToken]
            );
            uint256 stableUsdPrice = _getOraclePriceNormalized(stableUsdToken);
            if (stableUsdPrice > 0) {
                /// @dev Weighting the USD side of the pair by the price of the USD stable token if it exists.
                vars.usdStableTotal += (vars.stableUsdReserve * stableUsdPrice) / 1e18;
            } else {
                vars.usdStableTotal += vars.stableUsdReserve;
            }
            vars.tokenTotal += vars.tokenReserve;
        }
        return ((vars.usdStableTotal + vars.wNativeTotal) * 1e18) / vars.tokenTotal;
    }

    function getPrices(address[] calldata tokens, address factory)
        external
        view
        override
        returns (uint256[] memory prices)
    {
        prices = new uint256[](tokens.length);

        for (uint256 i; i < prices.length; i++) {
            address token = tokens[i];
            prices[i] = getPrice(token, factory);
        }
    }

    function _getOraclePriceNormalized(address token) internal view returns (uint256) {
        OracleInfo memory oracleInfo = tokenOracles[token];
        if (oracleInfo.oracleType == OracleType.CHAIN_LINK) {
            uint256 tokenUSDPrice = _getChainlinkPriceRaw(oracleInfo.oracleAddress);
            return _normalize(tokenUSDPrice, oracleInfo.oracleDecimals);
        }
        /// @dev Additional oracle types can be implemented here.
        // else if (oracleInfo.oracleType == OracleType.<NEW_ORACLE>) { }
        return 0;
    }

    function _getNativePrice(address factory) internal view returns (uint256) {
        uint256 oraclePrice = _getOraclePriceNormalized(wNative);
        if (oraclePrice > 0) {
            return oraclePrice;
        }
        /// @dev This method calculates the price of wNative by comparing multiple stable pools and weighting by their oracle price
        uint256 wNativeTotal = 0;
        uint256 usdStableTotal = 0;
        for (uint256 i = 0; i < stableUsdTokens.length; i++) {
            address stableUsdToken = stableUsdTokens[i];
            (uint256 wNativeReserve, uint256 stableUsdReserve) = _getNormalizedReservesFromFactory_Decimals(
                factory,
                wNative,
                stableUsdToken,
                _getTokenDecimals(wNative),
                stableUsdTokenDecimals[stableUsdToken]
            );
            uint256 stableUsdPrice = _getOraclePriceNormalized(stableUsdToken);
            if (stableUsdPrice > 0) {
                /// @dev Weighting the USD side of the pair by the price of the USD stable token if it exists.
                usdStableTotal += (stableUsdReserve * stableUsdPrice) / 1e18;
            } else {
                usdStableTotal += stableUsdReserve;
            }
            wNativeTotal += wNativeReserve;
        }
        return (usdStableTotal * 1e18) / wNativeTotal;
    }

    /**
     * @dev This private helper function takes in a DEX contract factory address and two token addresses (tokenA and tokenB).
     * It returns the current price of tokenA in terms of tokenB by dividing the normalized reserve value of tokenA
     * from the normalized reserve value of tokenB.
     *
     * Before calculating the price, it calls the internal _getNormalizedReservesFromFactory() function to retrieve
     * the normalized reserves of tokenA and tokenB. If either normalized reserve value is 0, it returns 0 for the price.
     *
     * @param factory The address of the DEX contract factory
     * @param tokenA Address of one of the tokens in the pair
     * @param tokenB Address of the other token in the pair
     * @return priceAForB The price of tokenA in terms of tokenB
     */
    // TODO: Make public? The idea here is that this function allows for path pricing. Where the front end can send a dynamic path and this could find the price between two addresses in the path.
    function _getPriceFromV2LP(
        address factory,
        address tokenA,
        address tokenB
    ) private view returns (uint256 priceAForB) {
        (uint256 normalizedReserveA, uint256 normalizedReserveB) = _getNormalizedReservesFromFactory(
            factory,
            tokenA,
            tokenB
        );

        if (normalizedReserveA == 0 || normalizedReserveA == 0) {
            return 0;
        }

        // Calculate the price of tokenA in terms of tokenB by dividing the normalized reserve value of tokenA
        // from the normalized reserve value of tokenB.
        priceAForB = (normalizedReserveA * (10**18)) / normalizedReserveB;
    }

    function _getNormalizedReservesFromFactory(
        address factory,
        address tokenA,
        address tokenB
    ) internal view returns (uint256 normalizedReserveA, uint256 normalizedReserveB) {
        address pairAddress = IApeFactory(factory).getPair(tokenA, tokenB);
        if (pairAddress == address(0)) {
            return (0, 0);
        }

        IApePair pair = IApePair(pairAddress);
        address token0 = pair.token0();
        address token1 = pair.token1();

        uint8 decimals0 = IERC20(token0).decimals();
        uint8 decimals1 = IERC20(token1).decimals();

        return _getNormalizedReservesFromPair_Decimals(pairAddress, token0, token1, decimals0, decimals1);
    }

    function _getNormalizedReservesFromFactory_Decimals(
        address factory,
        address tokenA,
        address tokenB,
        uint8 decimalsA,
        uint8 decimalsB
    ) internal view returns (uint256 normalizedReserveA, uint256 normalizedReserveB) {
        address pairAddress = IApeFactory(factory).getPair(tokenA, tokenB);
        if (pairAddress == address(0)) {
            return (0, 0);
        }
        return _getNormalizedReservesFromPair_Decimals(pairAddress, tokenA, tokenB, decimalsA, decimalsB);
    }

    /**
     * @dev This internal function takes in a pair address, two token addresses (tokenA and tokenB), and their respective decimals.
     * It returns the normalized reserves for each token in the pair.
     *
     * This function uses the IApePair interface to get the current reserves of the given token pair
     * If successful, it returns the normalized reserves for each token in the pair by calling _normalize() on
     * the reserve values. The order of the returned normalized reserve values depends on the lexicographic ordering
     * of tokenA and tokenB.
     *
     * @param pair Address of the liquidity pool contract representing the token pair
     * @param tokenA Address of one of the tokens in the pair
     * @param tokenB Address of the other token in the pair
     * @param decimalsA The number of decimals for tokenA
     * @param decimalsB The number of decimals for tokenB
     * @return normalizedReserveA The normalized reserve value for tokenA
     * @return normalizedReserveB The normalized reserve value for tokenB
     */
    function _getNormalizedReservesFromPair_Decimals(
        address pair,
        address tokenA,
        address tokenB,
        uint8 decimalsA,
        uint8 decimalsB
    ) internal view returns (uint256 normalizedReserveA, uint256 normalizedReserveB) {
        try IApePair(pair).getReserves() returns (uint112 reserve0, uint112 reserve1, uint32) {
            if (_isSorted(tokenA, tokenB)) {
                return (_normalize(reserve0, decimalsA), _normalize(reserve1, decimalsB));
            } else {
                return (_normalize(reserve1, decimalsA), _normalize(reserve0, decimalsB));
            }
        } catch {
            return (0, 0);
        }
    }

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
    function _normalizeToken(uint256 amount, address token) private view returns (uint256) {
        return _normalize(amount, _getTokenDecimals(token));
    }

    /// @notice Normalize the amount passed to wei or 1e18 decimals
    function _normalize(uint256 amount, uint8 decimals) private pure returns (uint256) {
        return (amount * (10**18)) / (10**decimals);
    }
}
