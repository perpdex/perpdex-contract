// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { PoolLibrary } from "../lib/PoolLibrary.sol";
import { MarketStructs } from "../lib/MarketStructs.sol";

contract TestPoolLibrary {
    constructor() {}

    MarketStructs.PoolInfo public poolInfo;

    function applyFunding(int256 fundingRateX96) external {
        PoolLibrary.applyFunding(poolInfo, fundingRateX96);
    }

    function setPoolInfo(MarketStructs.PoolInfo memory value) external {
        poolInfo = value;
    }
}
