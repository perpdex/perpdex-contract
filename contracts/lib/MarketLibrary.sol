// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import { IPerpdexMarket } from "../interface/IPerpdexMarket.sol";
import { PerpMath } from "./PerpMath.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/SafeCast.sol";

library MarketLibrary {
    using PerpMath for int256;
    using PerpMath for uint256;
    using SafeCast for uint256;

    function swap(
        address market,
        bool isBaseToQuote,
        bool isExactInput,
        uint256 amount
    ) internal returns (int256, int256) {
        uint256 resAmount = IPerpdexMarket(market).swap(isBaseToQuote, isExactInput, amount);
        return _processSwapResponse(isBaseToQuote, isExactInput, amount, resAmount);
    }

    function swapDry(
        address market,
        bool isBaseToQuote,
        bool isExactInput,
        uint256 amount
    ) internal view returns (int256, int256) {
        uint256 resAmount = IPerpdexMarket(market).swapDry(isBaseToQuote, isExactInput, amount);
        return _processSwapResponse(isBaseToQuote, isExactInput, amount, resAmount);
    }

    function _processSwapResponse(
        bool isBaseToQuote,
        bool isExactInput,
        uint256 amount,
        uint256 resAmount
    ) private pure returns (int256, int256) {
        if (isExactInput) {
            if (isBaseToQuote) {
                return (amount.neg256(), resAmount.toInt256());
            } else {
                return (resAmount.toInt256(), amount.neg256());
            }
        } else {
            if (isBaseToQuote) {
                return (resAmount.neg256(), amount.toInt256());
            } else {
                return (amount.toInt256(), resAmount.neg256());
            }
        }
    }
}
