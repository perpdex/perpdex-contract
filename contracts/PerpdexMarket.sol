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
    address public immutable priceFeedBase;
    address public immutable priceFeedQuote;

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
        address priceFeedBaseArg,
        address priceFeedQuoteArg
    ) {
        require(priceFeedBaseArg == address(0) || priceFeedBaseArg.isContract(), "PM_C: base price feed invalid");
        require(priceFeedQuoteArg == address(0) || priceFeedQuoteArg.isContract(), "PM_C: quote price feed invalid");

        symbol = symbolArg;
        exchange = exchangeArg;
        priceFeedBase = priceFeedBaseArg;
        priceFeedQuote = priceFeedQuoteArg;

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

        _processFunding();
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
            FundingLibrary.validateInitialLiquidityPrice(priceFeedBase, priceFeedQuote, baseShare, quoteBalance);
        }

        (base, quote, liquidity) = PoolLibrary.addLiquidity(
            poolInfo,
            PoolLibrary.AddLiquidityParams({ base: baseShare, quote: quoteBalance })
        );
        emit LiquidityAdded(base, quote, liquidity);

        _processFunding();
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
        emit LiquidityRemoved(base, quote, liquidity);

        _processFunding();
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
    ) external view override returns (uint256 oppositeAmount) {
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

    function _processFunding() internal {
        int256 fundingRateX96 =
            FundingLibrary.processFunding(
                fundingInfo,
                FundingLibrary.ProcessFundingParams({
                    priceFeedBase: priceFeedBase,
                    priceFeedQuote: priceFeedQuote,
                    markPriceX96: getMarkPriceX96(),
                    maxPremiumRatio: fundingMaxPremiumRatio,
                    maxElapsedSec: fundingMaxElapsedSec,
                    rolloverSec: fundingRolloverSec
                })
            );
        if (fundingRateX96 == 0) return;

        PoolLibrary.applyFunding(poolInfo, fundingRateX96);
        emit FundingPaid(fundingRateX96);
    }
}
