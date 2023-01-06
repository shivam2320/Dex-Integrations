// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../Interfaces/IDex.sol";

contract UniV2Provider is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address private constant NATIVE_TOKEN_ADDRESS =
        address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    IUniswapV2Router02 public swapRouter;

    event NativeFundsSwapped(
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    event ERC20FundsSwapped(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        uint256 amountOut
    );

    // Uniswap router address required
    constructor(IUniswapV2Router02 _swapRouter) {
        swapRouter = IUniswapV2Router02(_swapRouter);
    }

    /**
    // @notice function responsible to swap ERC20 -> ERC20
    // @param _tokenIn address of input token
    // @param _tokenOut address of output token
    // @param amountIn amount of input tokens
    // param extraData extra data if required
     */
    function swapERC20(
        address _tokenIn,
        address _tokenOut,
        uint256 amountIn,
        address _receiver
    ) external returns (uint256 amountOut) {
        uint256[] memory amountsOut;

        IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        IERC20(_tokenIn).safeApprove(address(swapRouter), amountIn);

        address[] memory path = new address[](2);
        path[0] = _tokenIn;
        path[1] = _tokenOut;

        if (_tokenOut == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            path[1] = swapRouter.WETH();
            amountsOut = swapRouter.getAmountsOut(amountIn, path);
            swapRouter.swapExactTokensForETH(
                amountIn,
                amountsOut[path.length - 1],
                path,
                _receiver,
                block.timestamp + 20
            );

            amountOut = amountsOut[path.length - 1];
        } else {
            amountsOut = swapRouter.getAmountsOut(amountIn, path);
            swapRouter.swapExactTokensForTokens(
                amountIn,
                amountsOut[path.length - 1],
                path,
                _receiver,
                block.timestamp + 20
            );

            amountOut = amountsOut[path.length - 1];
        }

        emit ERC20FundsSwapped(amountIn, _tokenIn, _tokenOut, amountOut);
    }

    /**
    // @notice function responsible to swap NATIVE -> ERC20
    // @param _tokenOut address of output token
    // param extraData extra data if required
     */
    function swapNative(address _tokenOut, address _receiver)
        external
        payable
        returns (uint256 amountOut)
    {
        uint256[] memory amountsOut;
        require(msg.value > 0, "Must pass non 0 ETH amount");

        //swapExactETHfortokens
        address[] memory path = new address[](2);
        path[0] = swapRouter.WETH();
        path[1] = _tokenOut;

        amountsOut = swapRouter.getAmountsOut(msg.value, path);

        swapRouter.swapExactETHForTokens{value: msg.value}(
            amountsOut[path.length - 1],
            path,
            _receiver,
            block.timestamp + 20
        );

        amountOut = amountsOut[path.length - 1];

        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "refund failed");

        emit NativeFundsSwapped(_tokenOut, msg.value, amountOut);
    }

    /**
	// @notice function responsible to rescue funds if any
	// @param  tokenAddr address of token
	 */
    function rescueFunds(address tokenAddr) external onlyOwner nonReentrant {
        if (tokenAddr == NATIVE_TOKEN_ADDRESS) {
            uint256 balance = address(this).balance;
            payable(msg.sender).transfer(balance);
        } else {
            uint256 balance = IERC20(tokenAddr).balanceOf(address(this));
            IERC20(tokenAddr).transferFrom(address(this), msg.sender, balance);
        }
    }
}
