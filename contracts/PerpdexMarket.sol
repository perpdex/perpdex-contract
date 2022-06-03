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

    uint24 public poolFeeRatio;
    uint24 public fundingMaxPremiumRatio;
    uint32 public fundingMaxElapsedSec;
    uint32 public fundingRolloverSec;

    modifier onlyExchange() {
        // BT_CNCH: caller not Exchange
        require(exchange == msg.sender, "BT_CNE");
        _;
    }

    constructor(
        string memory symbolArg,
        address exchangeArg,
        address priceFeedArg
    ) {
        // BT_EANC: exchangeArg address is not contract
        require(exchangeArg.isContract(), "BT_EANC");

        // BT_SANC: Price feed address is not contract
        require(priceFeedArg.isContract(), "BT_PANC");

        symbol = symbolArg;
        exchange = exchangeArg;
        priceFeed = priceFeedArg;

        FundingLibrary.initializeFunding(fundingInfo);
        PoolLibrary.initializePool(poolInfo);

        poolFeeRatio = 3e3;
        fundingMaxPremiumRatio = 1e4;
        fundingMaxElapsedSec = 1 days;
        fundingRolloverSec = 1 days;
    }

    function swap(
        bool isBaseToQuote,
        bool isExactInput,
        uint256 amount
    ) external override onlyExchange nonReentrant returns (uint256) {
        _rebase();
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
        onlyExchange
        nonReentrant
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        _rebase();

        if (poolInfo.totalLiquidity == 0) {
            // TODO: check if reasonable price
        }

        return
            PoolLibrary.addLiquidity(
                poolInfo,
                PoolLibrary.AddLiquidityParams({ base: baseShare, quote: quoteBalance })
            );
    }

    function removeLiquidity(uint256 liquidity) external override onlyExchange nonReentrant returns (uint256, uint256) {
        _rebase();
        return PoolLibrary.removeLiquidity(poolInfo, PoolLibrary.RemoveLiquidityParams({ liquidity: liquidity }));
    }

    function setPoolFeeRatio(uint24 value) external onlyOwner nonReentrant {
        require(value < 1e6);
        poolFeeRatio = value;
    }

    function setFundingMaxPremiumRatio(uint24 value) external onlyOwner nonReentrant {
        require(value < 1e6);
        fundingMaxPremiumRatio = value;
    }

    function setFundingMaxElapsedSec(uint32 value) external onlyOwner nonReentrant {
        require(value <= 7 days);
        fundingMaxElapsedSec = value;
    }

    function setFundingRolloverSec(uint32 value) external onlyOwner nonReentrant {
        require(value <= 7 days);
        fundingRolloverSec = value;
    }

    function swapDry(
        bool isBaseToQuote,
        bool isExactInput,
        uint256 amount
    ) external view override onlyExchange returns (uint256) {
        (, MarketStructs.PoolInfo memory poolInfoOutput) = _rebaseDry();

        return
            PoolLibrary.swapDry(
                poolInfoOutput.base,
                poolInfoOutput.quote,
                PoolLibrary.SwapParams({
                    isBaseToQuote: isBaseToQuote,
                    isExactInput: isExactInput,
                    amount: amount,
                    feeRatio: poolFeeRatio
                })
            );
    }

    function getMarkPriceX96() external view override returns (uint256) {
        (, MarketStructs.PoolInfo memory poolInfoOutput) = _rebaseDry();
        return
            PoolLibrary.getMarkPriceX96(poolInfoOutput.base, poolInfoOutput.quote, poolInfoOutput.baseBalancePerShare);
    }

    function getShareMarkPriceX96() external view override returns (uint256) {
        (, MarketStructs.PoolInfo memory poolInfoOutput) = _rebaseDry();
        return PoolLibrary.getShareMarkPriceX96(poolInfoOutput.base, poolInfoOutput.quote);
    }

    function getLiquidityValue(uint256 liquidity) external view override returns (uint256, uint256) {
        (, MarketStructs.PoolInfo memory poolInfoOutput) = _rebaseDry();
        return PoolLibrary.getLiquidityValue(poolInfo, liquidity);
    }

    function getLiquidityDeleveraged(
        uint256 liquidity,
        uint256 cumDeleveragedBasePerLiquidity,
        uint256 cumDeleveragedQuotePerLiquidity
    ) external view override returns (uint256, uint256) {
        (, MarketStructs.PoolInfo memory poolInfoOutput) = _rebaseDry();
        return
            PoolLibrary.getLiquidityDeleveraged(
                poolInfoOutput.cumDeleveragedBasePerLiquidity,
                poolInfoOutput.cumDeleveragedQuotePerLiquidity,
                liquidity,
                cumDeleveragedBasePerLiquidity,
                cumDeleveragedQuotePerLiquidity
            );
    }

    function getCumDeleveragedPerLiquidity() external view override returns (uint256, uint256) {
        (, MarketStructs.PoolInfo memory poolInfoOutput) = _rebaseDry();
        return (poolInfoOutput.cumDeleveragedBasePerLiquidity, poolInfoOutput.cumDeleveragedQuotePerLiquidity);
    }

    function baseBalancePerShare() external view override returns (uint256) {
        (, MarketStructs.PoolInfo memory poolInfoOutput) = _rebaseDry();
        return poolInfoOutput.baseBalancePerShare;
    }

    function _getLastMarkPriceX96() private view returns (uint256) {
        return PoolLibrary.getMarkPriceX96(poolInfo.base, poolInfo.quote, poolInfo.baseBalancePerShare);
    }

    function _rebaseDry() private view returns (bool updating, MarketStructs.PoolInfo memory poolInfoOutput) {
        uint256 markPriceX96 = _getLastMarkPriceX96();

        (bool updating2, int256 fundingRateX96, , ) =
            FundingLibrary.rebaseDry(
                fundingInfo,
                FundingLibrary.RebaseParams({
                    priceFeed: priceFeed,
                    markPriceX96: markPriceX96,
                    maxPremiumRatio: fundingMaxPremiumRatio,
                    maxElapsedSec: fundingMaxElapsedSec,
                    rolloverSec: fundingRolloverSec
                })
            );

        if (updating2) {
            return PoolLibrary.applyFundingDry(poolInfo, fundingRateX96);
        } else {
            return (false, poolInfoOutput);
        }
    }

    function _rebase() private {
        (bool updating, MarketStructs.PoolInfo memory poolInfoOutput) = _rebaseDry();

        if (!updating) return;

        poolInfo.base = poolInfoOutput.base;
        poolInfo.quote = poolInfoOutput.quote;
        poolInfo.cumDeleveragedBasePerLiquidity = poolInfoOutput.cumDeleveragedBasePerLiquidity;
        poolInfo.cumDeleveragedQuotePerLiquidity = poolInfoOutput.cumDeleveragedQuotePerLiquidity;
        poolInfo.baseBalancePerShare = poolInfoOutput.baseBalancePerShare;
    }
}
