// SPDX-License-Identifier: MIT
pragma solidity=0.8.17;

interface ITradingPairExchange {
    function initialize(address _tokenA, address _tokenB) external;
    function getReserves() external view returns (uint _reserve0, uint _reserve1);
    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amountA, uint amountB);
}