// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.16;

/**
 * @title Interface for XfaiPool contract
 */
interface IXFAIPool {
    /**
     * @notice Called once by the factory at time of deployment
     * @param _token The ERC20 token address of the pool
     * @param _xfaiFactory The xfai Factory of the pool
     */
    function initialize(address _token, address _xfaiFactory) external;

    /**
     * @notice Get the current Xfai Core contract address
     * @dev Only the Xfai Core contract can modify the state of the pool
     */
    function getXfaiCore() external view returns (address);

    /**
     * @notice Get the current reserve and weight of the pool
     */
    function getStates() external view returns (uint, uint);

    /**
     * @notice Updates the reserve and weight.
     * @dev This function is linked. Only the latest Xfai Core contract can call it
     * @param _newReserve The latest token balance of the pool
     * @param _newWeight The latest xfETH balance of the pool
     */
    function update(uint _newReserve, uint _newWeight) external;

    /**
     * @notice transfer the pool's poolToken or xfETH
     * @dev This function is linked. Only the latest Xfai Core contract can call it.
     * @param _token The ERC20 token address
     * @param _to The recipient of the tokens
     * @param _value The amount of tokens
     */
    function linkedTransfer(address _token, address _to, uint256 _value) external;

    /**
     * @notice This function mints new ERC20 liquidity tokens
     * @dev This function is linked. Only the latest Xfai Core contract can call it
     * @param _to The recipient of the tokens
     * @param _amount The amount of tokens
     */
    function mint(address _to, uint _amount) external;

    /**
     * @notice This function burns existing ERC20 liquidity tokens
     * @dev This function is linked. Only the latest Xfai Core contract can call it
     * @param _to The recipient whose tokens get burned
     * @param _amount The amount of tokens burned
     */
    function burn(address _to, uint _amount) external;

    /**
     * @notice The ERC20 token address of the pool's underlying token
     * @dev Not to be confused with the liquidity token address
     */
    function poolToken() external view returns (address);

    /**
     * @notice Emitted when the reserve and weight are updated
     * @param newReserve The new reserve amount
     * @param newWeight The new weight amount
     */
    event Sync(uint newReserve, uint newWeight);
}
