// SPDX-License-Identifier: MIT
pragma solidity=0.8.17;

interface IRouter {
    function addLiquidity(address tokenA, address tokenB, uint amountADesired, uint amountBDesired, uint amountAMin, uint amountBMin, address to) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
    function removeLiquidity(address tokenA, address tokenB, uint liquidity ,uint amountAMin, uint amountBMin, address to) external returns(uint amountA, uint amountB);
}