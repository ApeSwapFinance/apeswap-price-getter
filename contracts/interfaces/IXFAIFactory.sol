// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.16;

/**
 * @title Interface for XfaiFactory contract
 */
interface IXFAIFactory {
    /**
     * @notice Returns the length of the allPools array, representing the number of pools hosted on the DEX
     */
    function allPoolsLength() external view returns (uint);

    /**
     * @notice Computes the code hash of the XfaiPool contract
     */
    function poolCodeHash() external pure returns (bytes32);

    /**
     * @notice Creates an XfaiPool for a given ERC20 token
     * @dev Notice, _token cannot be the wETH token address
     * @param _token The token address of an ERC20 token
     * @return pool The address of the created XfaiPool
     */
    function createPool(address _token) external returns (address pool);

    /**
     * @notice Assigns a new Xfai Core to Xfai
     * @dev Can only be called by owner
     * @param _core The address of the new Xfai Core contract
     */
    function setXfaiCore(address _core) external;

    /**
     * @notice Used to receive the latest Xfai Core address
     */
    function getXfaiCore() external view returns (address);

    /**
     * @notice Assigns a new owner to the factory
     * @dev Can only be called by owner
     * @param _owner The address of the new owner
     */
    function setOwner(address _owner) external;

    /**
     * @notice Used to return the owner of the factory
     */
    function getOwner() external view returns (address);

    /**
     * @notice The address array of all deployed XfaiPool contracts
     */
    function allPools(uint index) external view returns (address);

    /**
     * @notice The address mapping from hosted tokens to pool address
     */
    function getPool(address _token) external view returns (address);

    /**
     * @notice Emitted when a new pool is created
     * @param token The address of the token for which the pool is created
     * @param pool The address of the created pool
     * @param allPoolsLength The current length of the allPools array
     */
    event PoolCreated(address indexed token, address indexed pool, uint allPoolsLength);

    /**
     * @notice Emitted when the core contract address is changed
     * @param newCore The address of the new core contract
     */
    event ChangedCore(address indexed newCore);

    /**
     * @notice Emitted when the owner address is changed
     * @param newOwner The address of the new owner
     */
    event ChangedOwner(address indexed newOwner);
}
