// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.5.0;

interface IWNATIVE {
    function deposit() external payable;

    function transfer(address to, uint value) external returns (bool);

    function withdraw(uint) external;
}
