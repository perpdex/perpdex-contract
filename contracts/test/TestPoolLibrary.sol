// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { PoolLibrary } from "../lib/PoolLibrary.sol";
import { MarketStructs } from "../lib/MarketStructs.sol";

contract TestPoolLibrary {
    constructor() {}

    event SwapResult(uint256 oppositeAmount);

    MarketStructs.PoolInfo public poolInfo;

    function applyFunding(int256 fundingRateX96) external {
        PoolLibrary.applyFunding(poolInfo, fundingRateX96);
    }

    function swap(PoolLibrary.SwapParams memory params) external {
        uint256 oppositeAmount = PoolLibrary.swap(poolInfo, params);
        emit SwapResult(oppositeAmount);
    }

    function previewSwap(
        uint256 base,
        uint256 quote,
        PoolLibrary.SwapParams memory params
    ) external pure returns (uint256) {
        return PoolLibrary.previewSwap(base, quote, params);
    }

    function setPoolInfo(MarketStructs.PoolInfo memory value) external {
        poolInfo = value;
    }
}
