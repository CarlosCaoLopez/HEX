// SPDX-License-Identifier: MIT
pragma solidity=0.8.17;

import "../core/interfaces/IHexswapV2ERC20.sol";
import './interfaces/IRouter.sol' ;
import '../core/interfaces/IFactory.sol';
import '../libraries/HexLibrary.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';


contract Router is IRouter {

    address public immutable factory; /* More explicit than IFactory public immutable factory; */
    

    constructor(address _factoryAddr) {
        factory = _factoryAddr;
    }
    /*** 
     * 
     * 
     * uint amountADesired: how many do the tokenA do you want to deposit ideally
     * uint amountBDesired: how many do the tokenB do you want to deposit ideally
     * uint amountAMin: how many do the tokenA do you want to deposit at least
     * uint amountBMin: how many do the tokenB do you want to deposit at least
    ***/

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal returns (uint256 amountA, uint256 amountB){
        /*If tradingPairContract does not exist then create it */
        if(IFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            IFactory(factory).createPair(tokenA, tokenB);
        }
        /* How many tokenA and tokenB does de pool have? */
        (uint reserveA, uint reserveB) = HexLibrary.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) { /* If there is no tokenA or tokenB, pool is being initialize -> apply liquidity formula1 with the amount you want */
            (amountA, amountB) = (amountADesired, amountBDesired);
        }
        else{
           uint amountBOptimal = HexLibrary.quote(amountADesired, reserveA, reserveB); /* Given how many I want to deposit of the asset A, how many of asset B must I deposit? */
           if(amountBOptimal <= amountBDesired) {
            require(amountBOptimal >= amountBMin, 'HexRouter: INSUFFICIENTE_B_AMOUNT');
           } else { /* Same check that before but with asset A */
                uint amountAOptimal = HexLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'UniswapV2Router: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
           }
        }

        
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity){
        
        /* Compute the amounts of both assets */
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        /* What's the pairs address?  */
        address pair = HexLibrary.pairFor(factory, tokenA, tokenB);
        /* Transfer the amounts computed to the pairs contract */
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA); 
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);

        /* Mint the tokens to the LP */
        liquidity = ITradingPairExchange(pair).mint(to);
     }

    function removeLiquidity(address tokenA, address tokenB, uint liquidity ,uint amountAMin, uint amountBMin, address to) external returns(uint amountA, uint amountB) {
        address pair = IFactory(factory).getPair(tokenA, tokenB);
        /* User sends liquiidty to pair contract */
        IHexswapV2ERC20(pair).transferFrom(msg.sender, pair, liquidity); 
        (uint amount0, uint amount1) = ITradingPairExchange(pair).burn(to); // burn the liquidity tokens os the LP and transfer tokenA and tokenB to the LP 
        (address token0, ) = HexLibrary.sortTokens(tokenA, tokenB); // Just need token0
        (amountA, amountB) = token0 == tokenA ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, "HexswapV2Router: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "HexswapV2Router: INSUFFICIENT_B_AMOUNT");

    }
     
}
