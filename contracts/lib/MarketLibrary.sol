// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import { IPerpdexMarket } from "../interface/IPerpdexMarket.sol";
import { PerpMath } from "./PerpMath.sol";
import { PerpSafeCast } from "./PerpSafeCast.sol";

library MarketLibrary {
    using PerpMath for int256;
    using PerpMath for uint256;
    using PerpSafeCast for uint256;

    function swap(
        address market,
        bool isBaseToQuote,
        bool isExactInput,
        uint256 amount,
        uint256 oppositeAmountBound
    ) internal returns (int256, int256) {
        uint256 resAmount = IPerpdexMarket(market).swap(isBaseToQuote, isExactInput, amount);

        if (isExactInput) {
            require(resAmount >= oppositeAmountBound);
            if (isBaseToQuote) {
                return (amount.neg256(), resAmount.toInt256());
            } else {
                return (resAmount.toInt256(), amount.neg256());
            }
        } else {
            require(resAmount <= oppositeAmountBound);
            if (isBaseToQuote) {
                return (resAmount.neg256(), amount.toInt256());
            } else {
                return (amount.toInt256(), resAmount.neg256());
            }
        }
    }

    function balanceToShare(address market, int256 balance) internal view returns (int256) {
        uint256 shareAbs = IPerpdexMarket(market).balanceToShare(balance.abs());
        return balance < 0 ? shareAbs.neg256() : shareAbs.toInt256();
    }

    function shareToBalance(address market, int256 share) internal view returns (int256) {
        uint256 balanceAbs = IPerpdexMarket(market).shareToBalance(share.abs());
        return share < 0 ? balanceAbs.neg256() : balanceAbs.toInt256();
    }
}
