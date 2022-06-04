// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { FundingLibrary } from "../lib/FundingLibrary.sol";
import { MarketStructs } from "../lib/MarketStructs.sol";

contract TestFundingLibrary {
    constructor() {}

    event ProcessFundingResult(int256 fundingRateX96);

    MarketStructs.FundingInfo public fundingInfo;

    function processFunding(FundingLibrary.ProcessFundingParams memory params) external {
        int256 fundingRateX96 = FundingLibrary.processFunding(fundingInfo, params);
        emit ProcessFundingResult(fundingRateX96);
    }

    function validateInitialLiquidityPrice(
        address priceFeedBase,
        address priceFeedQuote,
        uint256 base,
        uint256 quote
    ) external view {
        FundingLibrary.validateInitialLiquidityPrice(priceFeedBase, priceFeedQuote, base, quote);
    }

    function setFundingInfo(MarketStructs.FundingInfo memory value) external {
        fundingInfo = value;
    }
}
