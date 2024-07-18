// SPDX-License-Identifier: MIT
pragma solidity=0.8.17;

import './interfaces/IFactory.sol';
import './interfaces/ITradingPairExchange.sol';
import './TradingPairExchange.sol';

contract Factory is IFactory {
    mapping(address => mapping(address => address)) public getPair;
    address[] public allTradingPairs;

    function createPair(address tokenA, address tokenB) external returns (address pair) {

        require(tokenA != tokenB, 'DEX: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA); 
        /* Ordering addresses so we store in a consistent way the ordering pairs in the mapping */
        require(token0 != address(0) && token1 != address(0), 'DEX: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'DEX: PAIR_EXISTS');

        /* Bytecode from the main core contract TradingPairexchanage.sol */
        bytes memory bytecode = type(TradingPairExchange).creationCode; 
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));

        /* Using the opcode create2 we create the address for the new contract pair deterministiclly (pre-compute de address)   */
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt) /* Check this line on https://github.com/Uniswap/v2-core/blob/ee547b17853e71ed4e0101ccfd52e70d5acded58/contracts/UniswapV2Factory.sol#L30-L32  */
        }

        ITradingPairExchange(pair).initialize(token0, token1); /* Creating the pool. Why initialize function inteaad of constructor?  */
        getPair[token0][token1] = pair;
        allTradingPairs.push(pair);

        emit TradingPairCreated(token0, token1);
    }
}