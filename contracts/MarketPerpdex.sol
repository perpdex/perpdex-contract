// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { IMarket } from "./interface/IMarket.sol";
import { MarketStructs } from "./lib/MarketStructs.sol";
import { FundingLibrary } from "./lib/FundingLibrary.sol";
import { PoolLibrary } from "./lib/PoolLibrary.sol";

contract MarketPerpdex is IMarket {
    using Address for address;
    using SafeMath for uint256;

    string public symbol;
    address public immutable clearingHouse;
    address public immutable priceFeed;

    MarketStructs.PoolInfo public poolInfo;
    MarketStructs.FundingInfo public fundingInfo;

    uint24 public poolFeeRatio;
    uint24 public fundingMaxPremiumRatio;
    uint32 public fundingMaxElapsedSec;
    uint32 public fundingRolloverSec;

    modifier onlyClearingHouse() {
        // BT_CNCH: caller not clearingHouse
        require(clearingHouse == msg.sender, "BT_CNCH");
        _;
    }

    constructor(
        string memory symbolArg,
        address clearingHouseArg,
        address priceFeedArg
    ) {
        // BT_CANC: ClearingHouse address is not contract
        require(clearingHouseArg.isContract(), "BT_CANC");

        // BT_SANC: Price feed address is not contract
        require(priceFeedArg.isContract(), "BT_PANC");

        symbol = symbolArg;
        clearingHouse = clearingHouseArg;
        priceFeed = priceFeedArg;
    }

    function swap(
        bool isBaseToQuote,
        bool isExactInput,
        uint256 amount
    ) external override onlyClearingHouse returns (uint256) {
        return
            PoolLibrary.swap(
                poolInfo,
                PoolLibrary.SwapParams({
                    isBaseToQuote: isBaseToQuote,
                    isExactInput: isExactInput,
                    amount: amount,
                    feeRatio: poolFeeRatio
                })
            );
    }

    function addLiquidity(uint256 baseShare, uint256 quoteBalance)
        external
        override
        onlyClearingHouse
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return
            PoolLibrary.addLiquidity(
                poolInfo,
                PoolLibrary.AddLiquidityParams({ base: baseShare, quote: quoteBalance })
            );
    }

    function removeLiquidity(uint256 liquidity) external override onlyClearingHouse returns (uint256, uint256) {
        return PoolLibrary.removeLiquidity(poolInfo, PoolLibrary.RemoveLiquidityParams({ liquidity: liquidity }));
    }

    function rebase() external override onlyClearingHouse {
        uint256 markPriceX96 = getMarkPriceX96();

        FundingLibrary.rebase(
            fundingInfo,
            FundingLibrary.RebaseParams({
                priceFeed: priceFeed,
                markPriceX96: markPriceX96,
                maxPremiumRatio: fundingMaxPremiumRatio,
                maxElapsedSec: fundingMaxElapsedSec,
                rolloverSec: fundingRolloverSec
            })
        );
    }

    function setPoolFeeRatio(uint24 value) external {
        require(value < 1e6);
        poolFeeRatio = value;
    }

    function setFundingMaxPremiumRatio(uint24 value) external {
        require(value < 1e6);
        fundingMaxPremiumRatio = value;
    }

    function setFundingMaxElapsedSec(uint32 value) external {
        require(value <= 7 days);
        fundingMaxElapsedSec = value;
    }

    function setFundingRolloverSec(uint32 value) external {
        require(value <= 7 days);
        fundingRolloverSec = value;
    }

    function getMarkPriceX96() public view override returns (uint256) {
        return PoolLibrary.getMarkPriceX96(poolInfo).div(fundingInfo.balancePerShare);
    }

    function shareToBalance(uint256 share) external view override returns (uint256) {
        return share.mul(fundingInfo.balancePerShare);
    }

    function balanceToShare(uint256 balance) external view override returns (uint256) {
        return balance.div(fundingInfo.balancePerShare);
    }
}
