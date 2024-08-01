// SPDX-License-Identifier: MIT
pragma solidity=0.8.17;

import './interfaces/IERC20.sol';
import './interfaces/ITradingPairExchange.sol';
import '../libraries/Math.sol';
import './HexswapV2ERC20.sol';
import './interfaces/IHexswapV2Callee.sol';
import './interfaces/IFactory.sol';

contract TradingPairExchange is ITradingPairExchange, HexswapV2ERC20 {

    uint public constant MINIMUM_LIQUIDITY = 10**3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    address public factoryAddr;
    address public token0;
    address public token1;

    /* How many of each token does it have */
    uint private reserve0;
    uint private reserve1;

    uint public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    uint private unlocked = 1;

    modifier lock() {
        require(unlocked == 1, 'HexswapV2: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor() {
        factoryAddr = msg.sender;
    }

    function initialize(address _token0, address _token1) external {
        require(msg.sender == factoryAddr, 'DEX: FORBIDDEN');
        token0 = _token0;
        token1 = _token1;
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

    // if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    function _mintFee(uint _reserve0, uint _reserve1) private returns (bool feeOn) {
        address feeTo = IFactory(factoryAddr).feeTo();
        feeOn = feeTo != address(0);
        uint _kLast = kLast; // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = Math.sqrt(_reserve0 * _reserve1);
                uint rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint numerator = totalSupply * (rootK - rootKLast);
                    uint denominator = rootK * 5 + rootKLast;
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    function mint(address to) external lock returns (uint liquidity){
        // To compute the liquidity, we need to know hoy many de LP has deposited 
        // How many we have last time
        (uint _reserve0, uint _reserve1) = getReserves(); 
        // How many do we have now
        uint balance0 = IHexswapV2ERC20(token0).balanceOf(address(this));
        uint balance1 = IHexswapV2ERC20(token1).balanceOf(address(this));

        uint depositedA = balance0 - _reserve0;
        uint depositedB = balance1 - _reserve1;

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply;

        // pool being initialiced?
        if(_totalSupply == 0){
            liquidity = Math.sqrt(depositedA * depositedB);
            _mint(address(0), MINIMUM_LIQUIDITY);
        }
        else{
            liquidity = Math.min(depositedA * _totalSupply / _reserve0, depositedB * _totalSupply / _reserve1); // Toma el minimo de una regla de tres simple
        }
        require(liquidity > 0, "HexswapV2: INSUFFICIENT_LIQUIDITY_MINED");
        _mint(to, liquidity);

        // update reserves
        _update(balance0, balance1);
        if (feeOn) kLast = reserve0 * reserve1; // reserve0 and reserve1 are up-to-date
    }


    function burn(address to) external returns (uint amount0, uint amount1) {
        (uint _reserve0, uint _reserve1) = getReserves(); // gas savings
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        // Stuff we need to compute the formula
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        uint liquidity = balanceOf[address(this)]; // Liquidity that has been transfered from the LP to the pair contract

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        /* Computes the amount of each token */
        amount0 = liquidity * balance0 / _totalSupply; // Otro regla de 3
        amount1 = liquidity * balance1 / _totalSupply;

        /* Burn liquidity and transfer tokens */
        _burn(address(this), liquidity);
        _safeTransferFrom(_token0, to, amount0);
        _safeTransferFrom(_token1, to, amount1);

        /* Update balances of each token */
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1);
        if (feeOn) kLast = reserve0 * reserve1; // reserve0 and reserve1 are up-to-date


    }

    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock {
        require(amount0Out > 0 || amount1Out > 0, 'HexswapV2: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint _reserve0, uint _reserve1) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'HexswapV2: INSUFFICIENT_LIQUIDITY');
        
        uint balance0;
        uint balance1;

        {
        address _token0 = token0;
        address _token1 = token1;
        require(to != _token0 && to != _token1, 'HexswapV2: INVALID_TO');
        if(amount0Out > 0) _safeTransferFrom(_token0, to, amount0Out);
        if(amount1Out > 0) _safeTransferFrom(_token1, to, amount1Out);
        if (data.length > 0) IHexswapV2Callee(to).hexswapV2Call(msg.sender, amount0Out, amount1Out, data);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
        }
        /* We don't know if the user/pair have sent token0 or token1 */
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0; /* Is the current balance of the token0 greater than the balance expected after the output */
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'UniswapV2: INSUFFICIENT_INPUT_AMOUNT');
        { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
        uint balance0Adjusted = balance0 * 1000 - (amount0In * 3); /* Compute balance0 - 0.003 * amountIn but everything is multiplied by 1000 */
        uint balance1Adjusted = balance1 * 1000 - (amount1In * 3);
        require(balance0Adjusted * balance1Adjusted  >= _reserve0 * _reserve1 * 1000**2, 'HexswapV2: K');
        }

        _update(balance0, balance1);


    }

}