// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Dex {
    event LogUint(string message, uint256 value);

    IERC20 public token0;
    IERC20 public token1;

    uint256 public reserve0;
    uint256 public reserve1;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    constructor(address _token0, address _token1) {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }

    function _mint(address to, uint256 amount) internal {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function _burn(address from, uint256 amount) internal {
        balanceOf[from] -= amount;
        totalSupply -= amount;
    }

    function _update() internal {
        reserve0 = token0.balanceOf(address(this));
        reserve1 = token1.balanceOf(address(this));
    }

    function _sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _min(uint x, uint y) internal pure returns (uint) {
        return x <= y ? x : y;
    }

    function addLiquidity(uint256 _amount0, uint256 _amount1, uint256 minShares) external returns (uint256 shares) {
        _update();

        uint256 _reserve0 = reserve0;
        uint256 _reserve1 = reserve1;

        require(token0.allowance(msg.sender, address(this)) >= _amount0, "ERC20: insufficient allowance");
        require(token1.allowance(msg.sender, address(this)) >= _amount1, "ERC20: insufficient allowance");

        require(token0.balanceOf(msg.sender) >= _amount0, "ERC20: transfer amount exceeds balance");
        require(token1.balanceOf(msg.sender) >= _amount1, "ERC20: transfer amount exceeds balance");

        if (totalSupply == 0) {
            shares = _sqrt(_amount0 * _amount1);
        } else {
            uint256 optimalAmount1 = (_amount0 * _reserve1) / _reserve0;
            if (_amount1 > optimalAmount1) {
                _amount1 = optimalAmount1;
            } else {
                _amount0 = (_amount1 * _reserve0) / _reserve1;
            }

            shares = _min((_amount0 * totalSupply) / _reserve0, (_amount1 * totalSupply) / _reserve1);
        }

        require(shares > 0, "shares = 0");
        require(shares >= minShares, "shares < minShares");

        token0.transferFrom(msg.sender, address(this), _amount0);
        token1.transferFrom(msg.sender, address(this), _amount1);

        _mint(msg.sender, shares);

        _update();
    }

    function removeLiquidity(uint256 shares, uint256 minAmount0, uint256 minAmount1) external returns (uint256 amount0, uint256 amount1) {
        uint256 _reserve0 = reserve0;
        uint256 _reserve1 = reserve1;
        uint256 _totalSupply = totalSupply;

        amount0 = (shares * _reserve0) / _totalSupply;
        amount1 = (shares * _reserve1) / _totalSupply;

        require(amount0 >= minAmount0, "Insufficient amount0");
        require(amount1 >= minAmount1, "Insufficient amount1");

        _burn(msg.sender, shares);

        _update();

        token0.transfer(msg.sender, amount0);
        token1.transfer(msg.sender, amount1);

        _update();
    }

    function swap(uint256 amount0Out, uint256 amount1Out, uint256 minOutput) external returns (uint256 amountOut) {
        require(amount0Out == 0 || amount1Out == 0, "Invalid input");

        bool isToken0 = amount1Out == 0;
        (IERC20 tokenIn, IERC20 tokenOut, uint256 reserveIn, uint256 reserveOut) = isToken0
            ? (token0, token1, reserve0, reserve1)
            : (token1, token0, reserve1, reserve0);

        uint256 amountIn = isToken0 ? amount0Out : amount1Out;

        uint256 balanceBefore = tokenIn.balanceOf(address(this));

        tokenIn.transferFrom(msg.sender, address(this), amountIn);

        uint256 actualAmountIn = tokenIn.balanceOf(address(this)) - balanceBefore;

        uint256 amountInWithFee = (actualAmountIn * 999) / 1000;
        amountOut = (reserveOut * amountInWithFee) / (reserveIn + amountInWithFee);

        require(amountOut >= minOutput, "Insufficient output amount");

        tokenOut.transfer(msg.sender, amountOut);

        _update();
    }
}
