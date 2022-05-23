// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import { IBaseTokenNew } from "../interface/IBaseTokenNew.sol";
import { PerpMath } from "./PerpMath.sol";
import { PerpSafeCast } from "./PerpSafeCast.sol";

// internal
library BaseTokenLibrary {
    using PerpMath for int256;
    using PerpMath for uint256;
    using PerpSafeCast for uint256;

    function balanceToShare(address baseToken, int256 balance) internal view returns (int256) {
        uint256 shareAbs = IBaseTokenNew(baseToken).balanceToShare(balance.abs());
        return balance < 0 ? shareAbs.neg256() : shareAbs.toInt256();
    }

    function shareToBalance(address baseToken, int256 share) internal view returns (int256) {
        uint256 balanceAbs = IBaseTokenNew(baseToken).shareToBalance(share.abs());
        return share < 0 ? balanceAbs.neg256() : balanceAbs.toInt256();
    }
}
