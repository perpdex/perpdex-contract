// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import "./PerpdexStructs.sol";

library AccountLibrary {
    function getTotalAccountValue(PerpdexStructs.AccountInfo memory accountInfo) public pure returns (uint256) {
        return 0;
    }

    function getTotalPositionNotional(PerpdexStructs.AccountInfo memory accountInfo) public pure returns (uint256) {
        return 0;
    }

    function getMarginFraction(PerpdexStructs.AccountInfo memory accountInfo) public pure returns (uint256) {
        return 0;
    }

    function isLiquidatable(PerpdexStructs.AccountInfo memory accountInfo) public pure returns (bool) {
        return 0;
    }
}
