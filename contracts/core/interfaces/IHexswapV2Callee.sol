pragma solidity=0.8.17;

interface IHexswapV2Callee {
    function hexswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}