// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CurrencySwap is Ownable {
    // rate[tokenIn][tokenOut] = exchange rate in 1e18
    mapping(address => mapping(address => uint256)) public rate;

    event RateUpdated(address tokenIn, address tokenOut, uint256 newRate);
    event Swapped(address user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    constructor() Ownable(msg.sender) {}

    // ADMIN UPDATE RATE
    function setRate(address tokenIn, address tokenOut, uint256 newRate) external onlyOwner {
        require(tokenIn != tokenOut, "Same token");
        rate[tokenIn][tokenOut] = newRate;
        emit RateUpdated(tokenIn, tokenOut, newRate);
    }

    // SWAP FUNCTION
    function swap(address tokenIn, address tokenOut, uint256 amountIn)
        external
        returns (uint256 amountOut)
    {
        require(rate[tokenIn][tokenOut] > 0, "Rate unavailable");

        // calculate output
        amountOut = (amountIn * rate[tokenIn][tokenOut]) / 1e18;

        // transfer token in from user
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        // send out tokenOut
        IERC20(tokenOut).transfer(msg.sender, amountOut);

        emit Swapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    // ALLOW INNCHAIN TO SWAP ON BEHALF OF USERS (escrow swap)
    function swapFrom(address user, address tokenIn, address tokenOut, uint256 amountIn)
        external
        returns (uint256 amountOut)
    {
        require(rate[tokenIn][tokenOut] > 0, "Rate unavailable");

        amountOut = (amountIn * rate[tokenIn][tokenOut]) / 1e18;

        // take funds from InnChain escrow contract
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        // send swapped token back to InnChain escrow
        IERC20(tokenOut).transfer(msg.sender, amountOut);

        emit Swapped(user, tokenIn, tokenOut, amountIn, amountOut);
    }
}
