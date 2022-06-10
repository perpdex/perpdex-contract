// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { IPerpdexMarket } from "./interface/IPerpdexMarket.sol";
import { MarketStructs } from "./lib/MarketStructs.sol";
import { FundingLibrary } from "./lib/FundingLibrary.sol";
import { PoolLibrary } from "./lib/PoolLibrary.sol";
import { PriceLimitLibrary } from "./lib/PriceLimitLibrary.sol";

contract PerpdexMarket is IPerpdexMarket, ReentrancyGuard, Ownable {
    using Address for address;
    using SafeMath for uint256;

    event PoolFeeRatioChanged(uint24 value);
    event FundingMaxPremiumRatioChanged(uint24 value);
    event FundingMaxElapsedSecChanged(uint32 value);
    event FundingRolloverSecChanged(uint32 value);
    event PriceLimitConfigChanged(
        uint24 normalOrderRatio,
        uint24 liquidationRatio,
        uint24 emaNormalOrderRatio,
        uint24 emaLiquidationRatio,
        uint32 emaSec
    );

    string public override symbol;
    address public immutable override exchange;
    address public immutable priceFeedBase;
    address public immutable priceFeedQuote;

    MarketStructs.PoolInfo public poolInfo;
    MarketStructs.FundingInfo public fundingInfo;
    MarketStructs.PriceLimitInfo public priceLimitInfo;

    uint24 public poolFeeRatio = 3e3;
    uint24 public fundingMaxPremiumRatio = 1e4;
    uint32 public fundingMaxElapsedSec = 1 days;
    uint32 public fundingRolloverSec = 1 days;
    MarketStructs.PriceLimitConfig public priceLimitConfig =
        MarketStructs.PriceLimitConfig({
            normalOrderRatio: 5e4,
            liquidationRatio: 10e4,
            emaNormalOrderRatio: 20e4,
            emaLiquidationRatio: 25e4,
            emaSec: 5 minutes
        });

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
        uint256 amount,
        bool isLiquidation
    ) external override onlyExchange nonReentrant returns (uint256 oppositeAmount) {
        (uint256 maxAmount, MarketStructs.PriceLimitInfo memory updated) =
            _doMaxSwap(isBaseToQuote, isExactInput, isLiquidation);
        require(amount <= maxAmount, "PM_S: too large amount");

        oppositeAmount = PoolLibrary.swap(
            poolInfo,
            PoolLibrary.SwapParams({
                isBaseToQuote: isBaseToQuote,
                isExactInput: isExactInput,
                amount: amount,
                feeRatio: poolFeeRatio
            })
        );

        PriceLimitLibrary.update(priceLimitInfo, updated);

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
        emit PoolFeeRatioChanged(value);
    }

    function setFundingMaxPremiumRatio(uint24 value) external onlyOwner nonReentrant {
        require(value <= 1e5, "PM_SFMPR: too large");
        fundingMaxPremiumRatio = value;
        emit FundingMaxPremiumRatioChanged(value);
    }

    function setFundingMaxElapsedSec(uint32 value) external onlyOwner nonReentrant {
        require(value <= 7 days, "PM_SFMES: too large");
        fundingMaxElapsedSec = value;
        emit FundingMaxElapsedSecChanged(value);
    }

    function setFundingRolloverSec(uint32 value) external onlyOwner nonReentrant {
        require(value <= 7 days, "PM_SFRS: too large");
        require(value >= 1 hours, "PM_SFRS: too small");
        fundingRolloverSec = value;
        emit FundingRolloverSecChanged(value);
    }

    function setPriceLimitConfig(MarketStructs.PriceLimitConfig calldata value) external onlyOwner nonReentrant {
        require(value.liquidationRatio <= 5e5, "PE_SPLC: too large liquidation");
        require(value.normalOrderRatio <= value.liquidationRatio, "PE_SPLC: invalid");
        require(value.emaLiquidationRatio < 1e6, "PE_SPLC: ema too large liq");
        require(value.emaNormalOrderRatio <= value.emaLiquidationRatio, "PE_SPLC: ema invalid");
        priceLimitConfig = value;
        emit PriceLimitConfigChanged(
            value.normalOrderRatio,
            value.liquidationRatio,
            value.emaNormalOrderRatio,
            value.emaLiquidationRatio,
            value.emaSec
        );
    }

    function previewSwap(
        bool isBaseToQuote,
        bool isExactInput,
        uint256 amount,
        bool isLiquidation
    ) external view override returns (uint256 oppositeAmount) {
        (uint256 maxAmount, ) = _doMaxSwap(isBaseToQuote, isExactInput, isLiquidation);
        require(amount <= maxAmount, "PM_PS: too large amount");

        oppositeAmount = PoolLibrary.previewSwap(
            poolInfo.base,
            poolInfo.quote,
            PoolLibrary.SwapParams({
                isBaseToQuote: isBaseToQuote,
                isExactInput: isExactInput,
                amount: amount,
                feeRatio: poolFeeRatio
            }),
            false
        );
    }

    function maxSwap(
        bool isBaseToQuote,
        bool isExactInput,
        bool isLiquidation
    ) external view override returns (uint256 amount) {
        (amount, ) = _doMaxSwap(isBaseToQuote, isExactInput, isLiquidation);
    }

    function getShareMarkPriceX96() public view override returns (uint256) {
        return PoolLibrary.getShareMarkPriceX96(poolInfo.base, poolInfo.quote);
    }

    function getLiquidityValue(uint256 liquidity) external view override returns (uint256, uint256) {
        return PoolLibrary.getLiquidityValue(poolInfo, liquidity);
    }

    function getLiquidityDeleveraged(
        uint256 liquidity,
        uint256 cumBasePerLiquidityX96,
        uint256 cumQuotePerLiquidityX96
    ) external view override returns (int256, int256) {
        return
            PoolLibrary.getLiquidityDeleveraged(
                poolInfo.cumBasePerLiquidityX96,
                poolInfo.cumQuotePerLiquidityX96,
                liquidity,
                cumBasePerLiquidityX96,
                cumQuotePerLiquidityX96
            );
    }

    function getCumDeleveragedPerLiquidityX96() external view override returns (uint256, uint256) {
        return (poolInfo.cumBasePerLiquidityX96, poolInfo.cumQuotePerLiquidityX96);
    }

    function baseBalancePerShareX96() external view override returns (uint256) {
        return poolInfo.baseBalancePerShareX96;
    }

    function getMarkPriceX96() public view override returns (uint256) {
        return PoolLibrary.getMarkPriceX96(poolInfo.base, poolInfo.quote, poolInfo.baseBalancePerShareX96);
    }

    function _processFunding() internal {
        uint256 markPriceX96 = getMarkPriceX96();
        (int256 fundingRateX96, uint32 elapsedSec, int256 premiumX96) =
            FundingLibrary.processFunding(
                fundingInfo,
                FundingLibrary.ProcessFundingParams({
                    priceFeedBase: priceFeedBase,
                    priceFeedQuote: priceFeedQuote,
                    markPriceX96: markPriceX96,
                    maxPremiumRatio: fundingMaxPremiumRatio,
                    maxElapsedSec: fundingMaxElapsedSec,
                    rolloverSec: fundingRolloverSec
                })
            );
        if (fundingRateX96 == 0) return;

        PoolLibrary.applyFunding(poolInfo, fundingRateX96);
        emit FundingPaid(fundingRateX96, elapsedSec, premiumX96, markPriceX96);
    }

    function _doMaxSwap(
        bool isBaseToQuote,
        bool isExactInput,
        bool isLiquidation
    ) private view returns (uint256 amount, MarketStructs.PriceLimitInfo memory updated) {
        if (poolInfo.totalLiquidity == 0) return (0, updated);

        uint256 sharePriceBeforeX96 = getShareMarkPriceX96();
        updated = PriceLimitLibrary.updateDry(priceLimitInfo, priceLimitConfig, sharePriceBeforeX96);

        uint256 sharePriceBound;
        if (isBaseToQuote) {
            sharePriceBound = PriceLimitLibrary.minPrice(
                updated.referencePrice,
                updated.emaPrice,
                priceLimitConfig,
                isLiquidation
            );
            if (sharePriceBound >= sharePriceBeforeX96) return (0, updated);
        } else {
            sharePriceBound = PriceLimitLibrary.maxPrice(
                updated.referencePrice,
                updated.emaPrice,
                priceLimitConfig,
                isLiquidation
            );
            if (sharePriceBound <= sharePriceBeforeX96) return (0, updated);
        }
        amount = PoolLibrary.maxSwap(
            poolInfo.base,
            poolInfo.quote,
            isBaseToQuote,
            isExactInput,
            poolFeeRatio,
            sharePriceBound
        );
    }
}
