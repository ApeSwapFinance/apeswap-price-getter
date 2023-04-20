pragma solidity >=0.6.6;

interface IArrakisVaultV1 {
    function getUnderlyingBalances() external view returns (uint256 amount0Current, uint256 amount1Current);

    function totalSupply() external view returns (uint256);

    function token0() external view returns (address);

    function token1() external view returns (address);
}
