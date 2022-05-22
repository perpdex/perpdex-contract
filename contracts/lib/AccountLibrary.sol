// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import "./PerpdexStructs.sol";

library AccountLibrary {
    function getAccountValue(PerpdexStructs.AccountInfo storage accountInfo) public pure returns (int256) {
        return 0;
    }

    function getTotalPositionNotional(PerpdexStructs.AccountInfo storage accountInfo) public pure returns (uint256) {
        return 0;
    }

    function getMarginFraction(PerpdexStructs.AccountInfo storage accountInfo) public pure returns (int256) {
        return 0;
    }

    function isLiquidatable(PerpdexStructs.AccountInfo storage accountInfo) public pure returns (bool) {
        return false;
    }

    function hasEnoughInitialMargin(PerpdexStructs.AccountInfo storage accountInfo) public pure returns (bool) {
        return false;
    }
}
