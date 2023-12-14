// SPDX-License-Identifier: FrenswareV2BootlegDVD

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./SafeERC20.sol";
import "./IUniswapV2Router02.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract PawAggregateRouterControllerV2 is Ownable, IUniswapV3SwapCallback {
    ISwapRouter public uniswapV3Router;
    IUniswapV2Router01 public uniswapV2Router;
    using SafeERC20 for IERC20;

    address public feeReceiver;
    uint16 public feeDefault = 25; // 0.25 % swap fee
    uint16 public constant FEE_DENOMINATOR = 10000;
    uint16 public constant MAX_FEE_BP = 100; // 1 %

    constructor(
        address feeReceiver_,
        address _uniswapV3Router,
        address _uniswapV2Router //(sushi)
    ) {
        _setFeeReceiver(feeReceiver_);
        uniswapV3Router = ISwapRouter(_uniswapV3Router);
        uniswapV2Router = IUniswapV2Router01(_uniswapV2Router);
    }

    event setSwapFee(uint16 indexed fromFeeBP, uint16 indexed toFeeBP); // fees can be updated in the future via proposals and community votes
    event FeeReceiverChange(
        address indexed fromFeeReceiver,
        address indexed toFeeReceiver
    );
    event Swap(
        address indexed router,
        address indexed fromToken,
        address indexed toToken,
        uint256 amountIn,
        uint256 feesPaid
    );

    struct SwapDesc {
        IUniswapV2Router01 router;
        uint256 amountIn;
        uint256 amountOutMin;
        address[] path;
        address to;
        uint256 deadline;
        bool withFee;
    }

    modifier pathMinLength2(address[] memory _path) {
        _pathMinLength2(_path);
        _;
    }

    function setFeeReceiver(address _feeReceiver) external onlyOwner {
        _setFeeReceiver(_feeReceiver);
    }

    function setFeeBP(uint16 _feeDefault) external onlyOwner {
        require(
            _feeDefault <= FEE_DENOMINATOR,
            "UniswapV2Router01: fee _ FEE_DENOMINATOR"
        );
        require(_feeDefault <= MAX_FEE_BP, "UniswapV2Router01: fee _ MAX");

        emit setSwapFee(feeDefault, _feeDefault);
        feeDefault = _feeDefault;
    }

    function setUniswapV2Router(address _uniswapV2Router) external onlyOwner {
        uniswapV2Router = IUniswapV2Router01(_uniswapV2Router);
    }

    function setUniswapV3Router(address _uniswapV3Router) external onlyOwner {
        uniswapV3Router = ISwapRouter(_uniswapV3Router);
    }

    /////// settings over

    function getFeeData(uint256 _amount)
        external
        view
        returns (uint256 _fee, uint256 _left)
    {
        return _getFeeData(_amount);
    }

    function swapExactInputSingle(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn,
        address tokenOut,
        uint24 fee
    ) external {
        (uint256 feeAmount, uint256 amountInAfterFee) = _getFeeData(amountIn);

        //t ransfer tokens from the user to the contract
        IERC20(tokenIn).transferFrom(
            msg.sender,
            address(this),
            amountInAfterFee
        );
        IERC20(tokenIn).transferFrom(msg.sender, feeReceiver, feeAmount);
        IERC20(tokenIn).approve(address(uniswapV3Router), amountInAfterFee);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: fee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amountInAfterFee,
                amountOutMinimum: amountOutMin,
                sqrtPriceLimitX96: 0
            });

        uniswapV3Router.exactInputSingle(params);
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external override {
        (address token0, address token1) = abi.decode(data, (address, address));

        if (amount0Delta > 0) {
            IERC20(token0).transfer(msg.sender, uint256(amount0Delta));
        }
        if (amount1Delta > 0) {
            IERC20(token1).transfer(msg.sender, uint256(amount1Delta));
        }
    }

    function swapExactTokensForTokens(
        IUniswapV2Router01 router,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        return
            _swapExactTokensForTokens(
                SwapDesc({
                    router: router,
                    amountIn: amountIn,
                    amountOutMin: amountOutMin,
                    path: path,
                    to: to,
                    deadline: deadline,
                    withFee: false
                })
            );
    }

    function swapExactETHForTokens(
        IUniswapV2Router01 router,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts) {
        return
            _swapExactETHForTokens(
                SwapDesc({
                    router: router,
                    amountIn: address(this).balance,
                    amountOutMin: amountOutMin,
                    path: path,
                    to: to,
                    deadline: deadline,
                    withFee: false
                })
            );
    }

    function swapExactTokensForETH(
        IUniswapV2Router01 router,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        return
            _swapExactTokensForETH(
                SwapDesc({
                    router: router,
                    amountIn: amountIn,
                    amountOutMin: amountOutMin,
                    path: path,
                    to: to,
                    deadline: deadline,
                    withFee: false
                })
            );
    }

    function swapExactTokensForTokensWithFee(
        IUniswapV2Router01 router,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        return
            _swapExactTokensForTokens(
                SwapDesc({
                    router: router,
                    amountIn: amountIn,
                    amountOutMin: amountOutMin,
                    path: path,
                    to: to,
                    deadline: deadline,
                    withFee: true
                })
            );
    }

    function swapExactETHForTokensWithFee(
        IUniswapV2Router01 router,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts) {
        return
            _swapExactETHForTokens(
                SwapDesc({
                    router: router,
                    amountIn: address(this).balance,
                    amountOutMin: amountOutMin,
                    path: path,
                    to: to,
                    deadline: deadline,
                    withFee: true
                })
            );
    }

    function swapExactTokensForETHWithFee(
        IUniswapV2Router01 router,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        return
            _swapExactTokensForETH(
                SwapDesc({
                    router: router,
                    amountIn: amountIn,
                    amountOutMin: amountOutMin,
                    path: path,
                    to: to,
                    deadline: deadline,
                    withFee: true
                })
            );
    }

    function _setFeeReceiver(address _feeReceiver) internal {
        require(_feeReceiver != address(0));

        emit FeeReceiverChange(feeReceiver, _feeReceiver);
        feeReceiver = _feeReceiver;
    }

    function _getFeeData(uint256 _amount)
        internal
        view
        returns (uint256 _fee, uint256 _left)
    {
        _fee = (_amount * feeDefault) / FEE_DENOMINATOR;
        _left = _amount - _fee;
    }

    function _pathMinLength2(address[] memory _path) internal pure {
        require(_path.length >= 2, "UniswapV2Router: path < 2"); // more than 2 coming soon
    }

    function _swapExactTokensForTokens(SwapDesc memory swapDesc)
        internal
        pathMinLength2(swapDesc.path)
        returns (uint256[] memory amounts)
    {
        // if `path[0]` is zero the tx will fail because of SafeERC20
        IERC20 _fromToken = IERC20(swapDesc.path[0]);

        if (swapDesc.withFee) {
            (uint256 _fee, uint256 _left) = _getFeeData(swapDesc.amountIn);

            // send tokens to this contract for swapping (minus fees)
            _fromToken.safeTransferFrom(_msgSender(), address(this), _left);
            // send fees to fee receiver
            _fromToken.safeTransferFrom(_msgSender(), feeReceiver, _fee);

            // approve tx to router
            _fromToken.safeIncreaseAllowance(address(swapDesc.router), _left);

            emit Swap(
                address(swapDesc.router),
                swapDesc.path[0],
                swapDesc.path[swapDesc.path.length - 1],
                swapDesc.amountIn,
                _fee
            );

            return
                swapDesc.router.swapExactTokensForTokens(
                    _left,
                    swapDesc.amountOutMin,
                    swapDesc.path,
                    swapDesc.to,
                    swapDesc.deadline
                );
        }
        // send tokens to this contract for swapping
        _fromToken.safeTransferFrom(
            _msgSender(),
            address(this),
            swapDesc.amountIn
        );

        // approve tx to router
        _fromToken.safeIncreaseAllowance(
            address(swapDesc.router),
            swapDesc.amountIn
        );

        emit Swap(
            address(swapDesc.router),
            swapDesc.path[0],
            swapDesc.path[swapDesc.path.length - 1],
            swapDesc.amountIn,
            0
        );

        return
            swapDesc.router.swapExactTokensForTokens(
                swapDesc.amountIn,
                swapDesc.amountOutMin,
                swapDesc.path,
                swapDesc.to,
                swapDesc.deadline
            );
    }

    function _swapExactETHForTokens(SwapDesc memory swapDesc)
        internal
        pathMinLength2(swapDesc.path)
        returns (uint256[] memory amounts)
    {
        if (swapDesc.withFee) {
            (uint256 _fee, uint256 _left) = _getFeeData(swapDesc.amountIn);
            (bool sent, ) = feeReceiver.call{value: _fee}("");
            require(sent, "UniswapV2Router: Failed to send Ether");

            emit Swap(
                address(swapDesc.router),
                swapDesc.path[0],
                swapDesc.path[swapDesc.path.length - 1],
                swapDesc.amountIn,
                _fee
            );

            return
                swapDesc.router.swapExactETHForTokens{value: _left}(
                    swapDesc.amountOutMin,
                    swapDesc.path,
                    swapDesc.to,
                    swapDesc.deadline
                );
        }

        emit Swap(
            address(swapDesc.router),
            swapDesc.path[0],
            swapDesc.path[swapDesc.path.length - 1],
            swapDesc.amountIn,
            0
        );

        return
            swapDesc.router.swapExactETHForTokens{value: swapDesc.amountIn}(
                swapDesc.amountOutMin,
                swapDesc.path,
                swapDesc.to,
                swapDesc.deadline
            );
    }

    function _swapExactTokensForETH(SwapDesc memory swapDesc)
        internal
        pathMinLength2(swapDesc.path)
        returns (uint256[] memory amounts)
    {
        // if `path[0]` is zero the tx will fail because safeERC20
        IERC20 _fromToken = IERC20(swapDesc.path[0]);

        if (swapDesc.withFee) {
            (uint256 _fee, uint256 _left) = _getFeeData(swapDesc.amountIn);

            _fromToken.safeTransferFrom(_msgSender(), address(this), _left);
            _fromToken.safeTransferFrom(_msgSender(), feeReceiver, _fee);
            _fromToken.safeIncreaseAllowance(address(swapDesc.router), _left);

            emit Swap(
                address(swapDesc.router),
                swapDesc.path[0],
                swapDesc.path[swapDesc.path.length - 1],
                swapDesc.amountIn,
                _fee
            );

            return
                swapDesc.router.swapExactTokensForETH(
                    _left,
                    swapDesc.amountOutMin,
                    swapDesc.path,
                    swapDesc.to,
                    swapDesc.deadline
                );
        }
        _fromToken.safeTransferFrom(
            _msgSender(),
            address(this),
            swapDesc.amountIn
        );

        _fromToken.safeIncreaseAllowance(
            address(swapDesc.router),
            swapDesc.amountIn
        );

        emit Swap(
            address(swapDesc.router),
            swapDesc.path[0],
            swapDesc.path[swapDesc.path.length - 1],
            swapDesc.amountIn,
            0
        );

        return
            swapDesc.router.swapExactTokensForETH(
                swapDesc.amountIn,
                swapDesc.amountOutMin,
                swapDesc.path,
                swapDesc.to,
                swapDesc.deadline
            );
    }

    function swapTokensV2(
        address[] calldata path,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline
    ) external {
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        IERC20(path[0]).approve(address(uniswapV2Router), amountIn);

        uniswapV2Router.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            to,
            deadline
        );
    }

    function swapTokensV3(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn,
        address tokenOut,
        uint24 fee,
        address to,
        uint256 deadline
    ) external {
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).approve(address(uniswapV3Router), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: fee,
                recipient: to,
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: amountOutMin,
                sqrtPriceLimitX96: 0
            });

        uniswapV3Router.exactInputSingle(params);
    }
}
