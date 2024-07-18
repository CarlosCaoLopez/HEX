// SPDX-License-Identifier: MIT
pragma solidity=0.8.17;

import "../core/interfaces/ITradingPairExchange.sol";
// import "./SafeMath.sol";

library HexLibrary {
    // using SafeMath for uint;

    //returns sorted token addresses, use to handle retuned values from pairs sorted in this order    
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'HexLibrary: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'HexLibrary: ZERO_ADDRESS'); //Ordering before the check ensures that none of the addreses is the zero address
    }

    //calculates the CREATE2 address for a pair without external calls
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        //we dont have to create the address like we did on Factory.sol, just emuate CREATE2: check https://docs.openzeppelin.com/cli/2.8/deploying-with-create2
        pair = address(uint160(uint(keccak256(abi.encodePacked(
            'ff', //constant to prevent colisons with CREATE
            factory, // sender address
            keccak256(abi.encodePacked(token0, token1)), // salt: arbitrary value provided by sender 
            hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
        )))));
    }

    // fetch and sort the redderver for a pair
    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0, ) = sortTokens(tokenA, tokenB); //Do not take both, we want reserves ordered, not addresses
        (uint reserve0, uint reserve1) =  ITradingPairExchange(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }
    
    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'UniswapV2Library: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        amountB = amountA * reserveB / reserveA; /* amount tokenA * price of tokenA respect tokenB = amount tokenB */
    }

}

