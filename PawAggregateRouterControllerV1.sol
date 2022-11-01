// SPDX-License-Identifier: FrenswareV2BootlegDVD
pragma solidity =0.8.16;

import "./Ownable.sol";
import "./IERC20.sol";
import "./SafeERC20.sol";

import "./IUniswapV2Router01.sol";

contract PawAggregateRouterControllerV1 is Ownable {
    using SafeERC20 for IERC20;
    /***************
     ** Variables ** !!!!!!!!!!!!!!!!!!!!!!
     ***************/
    address public feeReceiver;
    uint16 public feeBP = 25; // = 0.25 % 

       // Team fees will be used to fund future developments of useful tools,
               // similar to this one but with additions such as one block of high no collateral borrowing,
                   // and being able to "line up" your trade route and execute arbitrage in one block (flash loans with no coding).
                       // as well as being able to automate a path of actions in a single transaction, not in several transactions
                              // ( ( so many different things could be done))
                                                                                         
    /***************
     ** Constants **
     ***************/
    /**
     * @dev BP (not blood pressure) = Percent * 100
     * @notice BP has to be <= FEE_DENOMINATOR
     * BP = FEE_DENOMINATOR -> 100 %
     */
    uint16 public constant FEE_DENOMINATOR = 10000;
    uint16 public constant MAX_FEE_BP = 100; // = 1 %

    /*****************
     ** Constructor **
     *****************/

    constructor(address feeReceiver_) {
        _setFeeReceiver(feeReceiver_);
    }

    /************
     ** Events **
     ************/

    event FeeBPChange(uint16 indexed fromFeeBP, uint16 indexed toFeeBP); // fees can be updated in the future by proposals and community votes
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

    /****************
     ** Structures **
     ****************/

    struct SwapDesc {
        IUniswapV2Router01 router;
        uint256 amountIn;
        uint256 amountOutMin;
        address[] path;
        address to;
        uint256 deadline;
        bool withFee;
    }

    /***************
     ** Modifiers **
     ***************/

    modifier pathMinLength2(address[] memory _path) {
        _pathMinLength2(_path);
        _;
    }

    /***********************
     ** Ownable Functions **
     ***********************/

    function setFeeReceiver(address _feeReceiver) external onlyOwner {
        _setFeeReceiver(_feeReceiver);
    }

    function setFeeBP(uint16 _feeBP) external onlyOwner {
        require(
            _feeBP <= FEE_DENOMINATOR,
            "UniswapV2Router01Intermediary: feeBP > FEE_DENOMINATOR"
        );
        require(
            _feeBP <= MAX_FEE_BP,
            "UniswapV2Router01Intermediary: feeBP > MAX_FEE_BP"
        );

        emit FeeBPChange(feeBP, _feeBP);

        feeBP = _feeBP;
    }

    /************************
     ** External Functions **
     ************************/

    function getFeeDetails(uint256 _amount)
        external
        view
        returns (uint256 _fee, uint256 _left)
    {
        return _getFeeDetails(_amount);
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

    /************************
     ** Internal Functions **
     ************************/

    function _setFeeReceiver(address _feeReceiver) internal {
        /// @dev avoid misuse by checking for zero address
        require(_feeReceiver != address(0));

        emit FeeReceiverChange(feeReceiver, _feeReceiver);

        feeReceiver = _feeReceiver;
    }

    function _getFeeDetails(uint256 _amount)
        internal
        view
        returns (uint256 _fee, uint256 _left)
    {
        _fee = (_amount * feeBP) / FEE_DENOMINATOR;
        _left = _amount - _fee;
    }

    function _pathMinLength2(address[] memory _path) internal pure {
        /// @dev path always has min. 2 tokens
        require(_path.length >= 2, "UniswapV2Router01Intermediary: path < 2");
    }

    function _swapExactTokensForTokens(SwapDesc memory swapDesc)
        internal
        pathMinLength2(swapDesc.path)
        returns (uint256[] memory amounts)
    {
        /// @dev if `path[0]` is zero the tx will fail because of SafeERC20
        IERC20 _fromToken = IERC20(swapDesc.path[0]);

        if (swapDesc.withFee) {
            (uint256 _fee, uint256 _left) = _getFeeDetails(swapDesc.amountIn);

            /// @dev send tokens to this contract for swapping (minus fees)
            _fromToken.safeTransferFrom(_msgSender(), address(this), _left);
            /// @dev send fees to fee receiver
            _fromToken.safeTransferFrom(_msgSender(), feeReceiver, _fee);

            /// @dev approve tx to router
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
        /// @dev send tokens to this contract for swapping
        _fromToken.safeTransferFrom(
            _msgSender(),
            address(this),
            swapDesc.amountIn
        );

        /// @dev approve tx to router
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
            (uint256 _fee, uint256 _left) = _getFeeDetails(swapDesc.amountIn);

            /// @dev send fees to fee receiver
            (bool sent, ) = feeReceiver.call{value: _fee}("");
            /// @dev check if Ether have been sent
            require(
                sent,
                "UniswapV2Router01Intermediary: Failed to send Ether"
            );

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
        /// @dev if `path[0]` is zero the tx will fail because of SafeERC20
        IERC20 _fromToken = IERC20(swapDesc.path[0]);

        if (swapDesc.withFee) {
            (uint256 _fee, uint256 _left) = _getFeeDetails(swapDesc.amountIn);

            /// @dev send tokens to this contract for swapping (minus fees)
            _fromToken.safeTransferFrom(_msgSender(), address(this), _left);
            /// @dev send fees to fee receiver
            _fromToken.safeTransferFrom(_msgSender(), feeReceiver, _fee);

            /// @dev approve tx to router
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
        /// @dev send tokens to this contract for swapping
        _fromToken.safeTransferFrom(
            _msgSender(),
            address(this),
            swapDesc.amountIn
        );

        /// @dev approve tx to router
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
}
