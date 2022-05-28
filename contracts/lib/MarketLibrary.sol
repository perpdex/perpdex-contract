// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import { IMarket } from "../interface/IMarket.sol";
import { PerpMath } from "./PerpMath.sol";
import { PerpSafeCast } from "./PerpSafeCast.sol";

// internal
library MarketLibrary {
    using PerpMath for int256;
    using PerpMath for uint256;
    using PerpSafeCast for uint256;

    function swap(
        address market,
        bool isBaseToQuote,
        bool isExactInput,
        uint256 amount
    ) internal returns (int256, int256) {
        uint256 resAmount = IMarket(market).swap(isBaseToQuote, isExactInput, amount);

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

    function balanceToShare(address market, int256 balance) internal view returns (int256) {
        uint256 shareAbs = IMarket(market).balanceToShare(balance.abs());
        return balance < 0 ? shareAbs.neg256() : shareAbs.toInt256();
    }

    function shareToBalance(address market, int256 share) internal view returns (int256) {
        uint256 balanceAbs = IMarket(market).shareToBalance(share.abs());
        return share < 0 ? balanceAbs.neg256() : balanceAbs.toInt256();
    }
}
