// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.16;

import "../IPriceGetterProtocol.sol";
import "../../IPriceGetter.sol";
import "../../lib/UtilityLibrary.sol";
import "./interfaces/ICurveTwocryptoOptimized.sol";
import "./interfaces/ICurveTwocryptoFactory.sol";

contract PriceGetterCurve is IPriceGetterProtocol {
    // ========== Get Token Prices ==========

    function getTokenPrice(
        address token,
        address factory,
        PriceGetterParams memory params
    ) public view override returns (uint256 price) {
        ICurveTwocryptoFactory curveFactory = ICurveTwocryptoFactory(factory);

        uint256 nativePrice = params.mainPriceGetter.getNativePrice(IPriceGetter.Protocol.Curve, address(curveFactory));
        if (token == params.wrappedNative.tokenAddress) {
            /// @dev Returning high total balance for wrappedNative to heavily weight value.
            return nativePrice;
        }

        uint256 priceAddition;
        uint256 foundPoolTokens;

        try curveFactory.find_pool_for_coins(token, params.wrappedNative.tokenAddress) returns (address _pool) {
            ICurveTwocryptoOptimized pool = ICurveTwocryptoOptimized(_pool);
            uint256 native_dy;
            if (pool.coins(0) == params.wrappedNative.tokenAddress) {
                try pool.get_dy(0, 1, params.nativeLiquidityThreshold) returns (uint256 _nativeDy) {
                    native_dy = _nativeDy;
                } catch {}
            } else {
                try pool.get_dy(1, 0, params.nativeLiquidityThreshold) returns (uint256 _nativeDy) {
                    native_dy = _nativeDy;
                } catch {}
            }

            if (native_dy != 0) {
                native_dy = ((1e36 / native_dy) * 1e18) / params.nativeLiquidityThreshold;
                priceAddition += (native_dy * nativePrice) / 1e18;
                foundPoolTokens++;
            }
        } catch {}

        for (uint256 i = 0; i < params.stableUsdTokens.length; i++) {
            IPriceGetter.TokenAndDecimals memory stableUsdToken = params.stableUsdTokens[i];
            try curveFactory.find_pool_for_coins(token, stableUsdToken.tokenAddress) returns (address _pool) {
                ICurveTwocryptoOptimized pool = ICurveTwocryptoOptimized(_pool);
                uint256 native_dy;
                if (pool.coins(0) == stableUsdToken.tokenAddress) {
                    try pool.get_dy(0, 1, 10 ** stableUsdToken.decimals) returns (uint256 _nativeDy) {
                        native_dy = _nativeDy;
                    } catch {}
                } else {
                    try pool.get_dy(1, 0, 10 ** stableUsdToken.decimals) returns (uint256 _nativeDy) {
                        native_dy = _nativeDy;
                    } catch {}
                }
                if (native_dy == 0) {
                    continue;
                }
                native_dy = (1e36 / native_dy);

                uint256 stableUsdPrice = params.mainPriceGetter.getOraclePriceNormalized(stableUsdToken.tokenAddress);
                if (stableUsdPrice > 0) {
                    priceAddition += (native_dy * stableUsdPrice) / 1e18;
                } else {
                    priceAddition += native_dy;
                }
                foundPoolTokens++;
            } catch {}
        }

        if (foundPoolTokens == 0) {
            return 0;
        }
        price = priceAddition / foundPoolTokens;
    }

    // ========== LP PRICE ==========

    function getLPPrice(
        address lp,
        address factory,
        PriceGetterParams memory params
    ) public view override returns (uint256 price) {
        //if not a LP, handle as a standard token
        try ICurveTwocryptoOptimized(lp).balances(0) returns (uint256 _balance0) {
            address token0 = ICurveTwocryptoOptimized(lp).coins(0);
            _balance0 = UtilityLibrary._normalizeToken(_balance0, token0);

            uint256 _balance1 = ICurveTwocryptoOptimized(lp).balances(1);
            address token1 = ICurveTwocryptoOptimized(lp).coins(1);
            _balance1 = UtilityLibrary._normalizeToken(_balance1, token1);

            uint256 _totalSupply = ICurveTwocryptoOptimized(lp).totalSupply();

            uint256 _price0 = params.mainPriceGetter.getTokenPrice(token0, IPriceGetter.Protocol.Curve, factory);
            uint256 _price1 = params.mainPriceGetter.getTokenPrice(token1, IPriceGetter.Protocol.Curve, factory);
            return (_price0 * _balance0 + _price1 * _balance1) / _totalSupply;
        } catch {
            /// @dev If the pair is not a valid LP, return the price of the token
            uint256 lpPrice = getTokenPrice(lp, factory, params);
            return lpPrice;
        }
    }

    // ========== NATIVE PRICE ==========

    function getNativePrice(
        address factory,
        PriceGetterParams memory params
    ) public view override returns (uint256 price) {
        ICurveTwocryptoFactory curveFactory = ICurveTwocryptoFactory(factory);

        uint256 priceAddition;
        uint256 foundPoolTokens;

        for (uint256 i = 0; i < params.stableUsdTokens.length; i++) {
            IPriceGetter.TokenAndDecimals memory stableUsdToken = params.stableUsdTokens[i];
            try
                curveFactory.find_pool_for_coins(params.wrappedNative.tokenAddress, stableUsdToken.tokenAddress)
            returns (address _pool) {
                ICurveTwocryptoOptimized pool = ICurveTwocryptoOptimized(_pool);
                uint256 native_dy;
                if (pool.coins(0) == stableUsdToken.tokenAddress) {
                    try pool.get_dy(0, 1, 10 ** stableUsdToken.decimals) returns (uint256 _nativeDy) {
                        native_dy = _nativeDy;
                    } catch {}
                } else {
                    try pool.get_dy(1, 0, 10 ** stableUsdToken.decimals) returns (uint256 _nativeDy) {
                        native_dy = _nativeDy;
                    } catch {}
                }
                if (native_dy == 0) {
                    continue;
                }
                native_dy = (1e36 / native_dy);

                uint256 stableUsdPrice = params.mainPriceGetter.getOraclePriceNormalized(stableUsdToken.tokenAddress);
                if (stableUsdPrice > 0) {
                    priceAddition += (native_dy * stableUsdPrice) / 1e18;
                } else {
                    priceAddition += native_dy;
                }
                foundPoolTokens++;
            } catch {}
        }

        if (foundPoolTokens == 0) {
            return 0;
        }
        price = priceAddition / foundPoolTokens;
    }
}
