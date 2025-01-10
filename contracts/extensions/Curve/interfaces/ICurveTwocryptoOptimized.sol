// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICurveTwocryptoOptimized {
    // Constructor
    function initialize(
        string memory _name,
        string memory _symbol,
        address[2] memory _coins,
        address _math,
        bytes32 _salt,
        uint256 packed_precisions,
        uint256 packed_gamma_A,
        uint256 packed_fee_params,
        uint256 packed_rebalancing_params,
        uint256 initial_price
    ) external;

    // Functions
    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external returns (uint256);

    function exchange(uint256 i, uint256 j, uint256 dx, uint256 min_dy, address receiver) external returns (uint256);

    function exchange_received(uint256 i, uint256 j, uint256 dx, uint256 min_dy) external returns (uint256);

    function exchange_received(
        uint256 i,
        uint256 j,
        uint256 dx,
        uint256 min_dy,
        address receiver
    ) external returns (uint256);

    function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount) external returns (uint256);

    function add_liquidity(
        uint256[2] memory amounts,
        uint256 min_mint_amount,
        address receiver
    ) external returns (uint256);

    function remove_liquidity(uint256 _amount, uint256[2] memory min_amounts) external returns (uint256[2] memory);

    function remove_liquidity(
        uint256 _amount,
        uint256[2] memory min_amounts,
        address receiver
    ) external returns (uint256[2] memory);

    function remove_liquidity_one_coin(uint256 token_amount, uint256 i, uint256 min_amount) external returns (uint256);

    function remove_liquidity_one_coin(
        uint256 token_amount,
        uint256 i,
        uint256 min_amount,
        address receiver
    ) external returns (uint256);

    function transferFrom(address _from, address _to, uint256 _value) external returns (bool);

    function transfer(address _to, uint256 _value) external returns (bool);

    function approve(address _spender, uint256 _value) external returns (bool);

    function permit(
        address _owner,
        address _spender,
        uint256 _value,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external returns (bool);

    function fee_receiver() external view returns (address);

    function admin() external view returns (address);

    function calc_token_amount(uint256[2] memory amounts, bool deposit) external view returns (uint256);

    function get_dy(uint256 i, uint256 j, uint256 dx) external view returns (uint256);

    function get_dx(uint256 i, uint256 j, uint256 dy) external view returns (uint256);

    function lp_price() external view returns (uint256);

    function get_virtual_price() external view returns (uint256);

    function price_oracle() external view returns (uint256);

    function price_scale() external view returns (uint256);

    function fee() external view returns (uint256);

    function calc_withdraw_one_coin(uint256 token_amount, uint256 i) external view returns (uint256);

    function calc_token_fee(uint256[2] memory amounts, uint256[2] memory xp) external view returns (uint256);

    function A() external view returns (uint256);

    function gamma() external view returns (uint256);

    function coins(uint256 index) external view returns (address);

    function balances(uint256 index) external view returns (uint256);

    function totalSupply() external view returns (uint256);
}
