// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { PerpSafeCast } from "../lib/PerpSafeCast.sol";
import { SignedSafeMathUpgradeable } from "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "../ClearingHousePerpdex.sol";
import "./TestAccountBalancePerpdex.sol";
import "./TestExchangePerpdex.sol";

contract TestClearingHousePerpdex is ClearingHousePerpdex {
    using PerpSafeCast for uint256;
    using SignedSafeMathUpgradeable for int256;

    uint256 private _testBlockTimestamp;

    function __TestClearingHouse_init(
        address configArg,
        address vaultArg,
        address quoteTokenArg,
        address uniV3FactoryArg,
        address exchangeArg,
        address accountBalanceArg,
        address insuranceFundArg
    ) external initializer {
        ClearingHousePerpdex.initialize(
            configArg,
            vaultArg,
            quoteTokenArg,
            uniV3FactoryArg,
            exchangeArg,
            accountBalanceArg,
            insuranceFundArg
        );
        _testBlockTimestamp = block.timestamp;
    }

    function setBlockTimestamp(uint256 blockTimestamp) external {
        TestAccountBalancePerpdex(_accountBalance).setBlockTimestamp(blockTimestamp);
        TestExchangePerpdex(_exchange).setBlockTimestamp(blockTimestamp);
        _testBlockTimestamp = blockTimestamp;
    }

    function getBlockTimestamp() external view returns (uint256) {
        return _testBlockTimestamp;
    }

    function _blockTimestamp() internal view override returns (uint256) {
        return _testBlockTimestamp;
    }

    //
    // BELOW WERE LEGACY EXTERNAL FUNCTION, MOVE TO HERE FOR THE TESTING, CAN BE REMOVE LATER ONCE WE CLEAN THE TESTS
    //

    struct SwapParams {
        address baseToken;
        bool isBaseToQuote;
        bool isExactInput;
        uint256 amount;
        uint160 sqrtPriceLimitX96; // price slippage protection
    }

    function swap(SwapParams memory params) external nonReentrant() returns (IExchangePerpdex.SwapResponse memory) {
        IAccountBalance(_accountBalance).registerBaseToken(_msgSender(), params.baseToken);

        IExchangePerpdex.SwapResponse memory response =
            IExchangePerpdex(_exchange).swap(
                IExchangePerpdex.SwapParams({
                    trader: _msgSender(),
                    baseToken: params.baseToken,
                    isBaseToQuote: params.isBaseToQuote,
                    isExactInput: params.isExactInput,
                    isClose: false,
                    amount: params.amount
                })
            );

        IAccountBalance(_accountBalance).modifyTakerBalance(
            _msgSender(),
            params.baseToken,
            response.exchangedPositionSize,
            response.exchangedPositionNotional.sub(response.fee.toInt256())
        );

        if (response.pnlToBeRealized != 0) {
            IAccountBalance(_accountBalance).settleQuoteToOwedRealizedPnl(
                _msgSender(),
                params.baseToken,
                response.pnlToBeRealized
            );
        }
        return response;
    }

    function getTokenBalance(address trader, address baseToken) external view returns (int256, int256) {
        int256 base = IAccountBalance(_accountBalance).getBase(trader, baseToken);
        int256 quote = IAccountBalance(_accountBalance).getQuote(trader, baseToken);
        return (base, quote);
    }
}
