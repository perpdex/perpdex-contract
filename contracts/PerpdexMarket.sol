// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { IPerpdexMarket } from "./interface/IPerpdexMarket.sol";
import { MarketStructs } from "./lib/MarketStructs.sol";
import { FundingLibrary } from "./lib/FundingLibrary.sol";
import { PoolLibrary } from "./lib/PoolLibrary.sol";

contract PerpdexMarket is IPerpdexMarket, ReentrancyGuard, Ownable {
    using Address for address;
    using SafeMath for uint256;

    string public override symbol;
    address public immutable override exchange;
    address public immutable priceFeed;

    MarketStructs.PoolInfo public poolInfo;
    MarketStructs.FundingInfo public fundingInfo;

    uint24 public poolFeeRatio = 3e3;
    uint24 public fundingMaxPremiumRatio = 1e4;
    uint32 public fundingMaxElapsedSec = 1 days;
    uint32 public fundingRolloverSec = 1 days;

    modifier onlyExchange() {
        require(exchange == msg.sender, "PM_OE: caller is not exchange");
        _;
    }

    constructor(
        string memory symbolArg,
        address exchangeArg,
        address priceFeedArg
    ) {
        // BT_SANC: Price feed address is not contract
        require(priceFeedArg.isContract(), "BT_PANC");

        symbol = symbolArg;
        exchange = exchangeArg;
        priceFeed = priceFeedArg;

        FundingLibrary.initializeFunding(fundingInfo);
        PoolLibrary.initializePool(poolInfo);
    }

    function swap(
        bool isBaseToQuote,
        bool isExactInput,
        uint256 amount
    ) external override onlyExchange nonReentrant returns (uint256 oppositeAmount) {
        oppositeAmount = PoolLibrary.swap(
            poolInfo,
            PoolLibrary.SwapParams({
                isBaseToQuote: isBaseToQuote,
                isExactInput: isExactInput,
                amount: amount,
                feeRatio: poolFeeRatio
            })
        );
        emit Swapped(isBaseToQuote, isExactInput, amount, oppositeAmount);

        _rebase();
    }

    function addLiquidity(uint256 baseShare, uint256 quoteBalance)
        external
        override
        onlyExchange
        nonReentrant
        returns (
            uint256 base,
            uint256 quote,
            uint256 liquidity
        )
    {
        if (poolInfo.totalLiquidity == 0) {
            // TODO: check if reasonable price
        }

        (base, quote, liquidity) = PoolLibrary.addLiquidity(
            poolInfo,
            PoolLibrary.AddLiquidityParams({ base: baseShare, quote: quoteBalance })
        );

        _rebase();
    }

    function removeLiquidity(uint256 liquidity)
        external
        override
        onlyExchange
        nonReentrant
        returns (uint256 base, uint256 quote)
    {
        (base, quote) = PoolLibrary.removeLiquidity(
            poolInfo,
            PoolLibrary.RemoveLiquidityParams({ liquidity: liquidity })
        );
        _rebase();
    }

    function setPoolFeeRatio(uint24 value) external onlyOwner nonReentrant {
        require(value <= 5e4, "PM_SPFR: too large");
        poolFeeRatio = value;
    }

    function setFundingMaxPremiumRatio(uint24 value) external onlyOwner nonReentrant {
        require(value <= 1e5, "PM_SFMPR: too large");
        fundingMaxPremiumRatio = value;
    }

    function setFundingMaxElapsedSec(uint32 value) external onlyOwner nonReentrant {
        require(value <= 7 days, "PM_SFMES: too large");
        fundingMaxElapsedSec = value;
    }

    function setFundingRolloverSec(uint32 value) external onlyOwner nonReentrant {
        require(value <= 7 days, "PM_SFRS: too large");
        fundingRolloverSec = value;
    }

    function swapDry(
        bool isBaseToQuote,
        bool isExactInput,
        uint256 amount
    ) external view override onlyExchange returns (uint256 oppositeAmount) {
        oppositeAmount = PoolLibrary.swapDry(
            poolInfo.base,
            poolInfo.quote,
            PoolLibrary.SwapParams({
                isBaseToQuote: isBaseToQuote,
                isExactInput: isExactInput,
                amount: amount,
                feeRatio: poolFeeRatio
            })
        );
    }

    function getMarkPriceX96() public view override returns (uint256) {
        return PoolLibrary.getMarkPriceX96(poolInfo.base, poolInfo.quote, poolInfo.baseBalancePerShare);
    }

    function getShareMarkPriceX96() external view override returns (uint256) {
        return PoolLibrary.getShareMarkPriceX96(poolInfo.base, poolInfo.quote);
    }

    function getLiquidityValue(uint256 liquidity) external view override returns (uint256, uint256) {
        return PoolLibrary.getLiquidityValue(poolInfo, liquidity);
    }

    function getLiquidityDeleveraged(
        uint256 liquidity,
        uint256 cumDeleveragedBasePerLiquidity,
        uint256 cumDeleveragedQuotePerLiquidity
    ) external view override returns (uint256, uint256) {
        return
            PoolLibrary.getLiquidityDeleveraged(
                poolInfo.cumDeleveragedBasePerLiquidity,
                poolInfo.cumDeleveragedQuotePerLiquidity,
                liquidity,
                cumDeleveragedBasePerLiquidity,
                cumDeleveragedQuotePerLiquidity
            );
    }

    function getCumDeleveragedPerLiquidity() external view override returns (uint256, uint256) {
        return (poolInfo.cumDeleveragedBasePerLiquidity, poolInfo.cumDeleveragedQuotePerLiquidity);
    }

    function baseBalancePerShare() external view override returns (uint256) {
        return poolInfo.baseBalancePerShare;
    }

    function _rebase() private {
        int256 fundingRateX96 =
            FundingLibrary.rebase(
                fundingInfo,
                FundingLibrary.RebaseParams({
                    priceFeed: priceFeed,
                    markPriceX96: getMarkPriceX96(),
                    maxPremiumRatio: fundingMaxPremiumRatio,
                    maxElapsedSec: fundingMaxElapsedSec,
                    rolloverSec: fundingRolloverSec
                })
            );
        return PoolLibrary.applyFunding(poolInfo, fundingRateX96);
    }
}
