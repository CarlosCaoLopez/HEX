// SPDX-License-Identifier: MIT
pragma solidity=0.8.17;

import './interfaces/IERC20.sol';
import './interfaces/ITradingPairExchange.sol';
import '../libraries/Math.sol';
import './HexswapV2ERC20.sol';

contract TradingPairExchange is ITradingPairExchange, HexswapV2ERC20 {

    uint public constant MINIMUM_LIQUIDITY = 10**3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    address public factoryAddr;
    address public tokenA;
    address public tokenB;

    uint private reserve0;
    uint private reserve1;

    constructor() {
        factoryAddr = msg.sender;
    }

    function initialize(address _tokenA, address _tokenB) external {
        require(msg.sender == factoryAddr, 'DEX: FORBIDDEN');
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    function getReserves() public view returns (uint _reserve0, uint _reserve1){
        _reserve1 = reserve0;
        _reserve0 = reserve1;
    }

    function _safeTransferFrom(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success == true && (data.length == 0 || abi.decode(data, (bool))), 'HexswapV2: TRANSFER_FAILED'); // Check that it doesn't returns anything or return true/false

    }

    function _update(uint balance0, uint balance1) private {
        // update reserves
        reserve0 = balance0;
        reserve1 = balance1;
    }

    function mint(address to) external returns (uint liquidity){
        // To compute the liquidity, we need to know hoy many de LP has deposited 
        // How many we have last time
        (uint _reserve0, uint _reserve1) = getReserves(); 
        // How many do we have now
        uint balance0 = IHexswapV2ERC20(tokenA).balanceOf(address(this));
        uint balance1 = IHexswapV2ERC20(tokenB).balanceOf(address(this));

        uint depositedA = balance0 - _reserve0;
        uint depositedB = balance1 - _reserve1;

        uint _totalSupply = totalSupply;

        // pool being initialiced?
        if(_totalSupply == 0){
            uint liquidity = Math.sqrt(depositedA * depositedB);
            _mint(address(0), MINIMUM_LIQUIDITY);
        }
        else{
            uint liquidity = Math.min(depositedA * _totalSupply / _reserve0, depositedB * _totalSupply / _reserve1); 
        }
        require(liquidity > 0, "HexswapV2: INSUFFICIENT_LIQUIDITY_MINED");
        _mint(to, liquidity);

        // update reserves
        _update(balance0, balance1);
        // TODO: EMIT EVENT MINT
    }


    function burn(address to) external returns (uint amountA, uint amountB) {

        address _tokenA = tokenA; // gas savings
        address _tokenB = tokenB; // gas savings
        // Stuff we need to compute the formula
        uint balance0 = IERC20(_tokenA).balanceOf(address(this));
        uint balance1 = IERC20(_tokenB).balanceOf(address(this));
        uint liquidity = balanceOf[address(this)]; // Liquidity that has been transfered from the LP to the pair contract

        /* Computes the amount of each token */
        uint amount0 = liquidity * balance0 / totalSupply;
        uint amount1 = liquidity * balance1 / totalSupply;

        /* Burn liquidity and transfer tokens */
        _burn(address(this), liquidity);
        _safeTransferFrom(_tokenA, to, amount0);
        _safeTransferFrom(_tokenB, to, amount0);

        /* Update balances of each token */
        balance0 = IERC20(_tokenA).balanceOf(address(this));
        balance1 = IERC20(_tokenB).balanceOf(address(this));

        _update(balance0, balance1);


    }

}