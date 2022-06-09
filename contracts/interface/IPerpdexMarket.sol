// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.7.6;
pragma abicoder v2;

interface IPerpdexMarket {
    event FundingPaid(int256 fundingRateX96);
    event LiquidityAdded(uint256 base, uint256 quote, uint256 liquidity);
    event LiquidityRemoved(uint256 base, uint256 quote, uint256 liquidity);
    event Swapped(bool isBaseToQuote, bool isExactInput, uint256 amount, uint256 oppositeAmount);

    function swap(
        bool isBaseToQuote,
        bool isExactInput,
        uint256 amount,
        bool isLiquidation
    ) external returns (uint256);

    function addLiquidity(uint256 baseShare, uint256 quoteBalance)
        external
        returns (
            uint256,
            uint256,
            uint256
        );

    function removeLiquidity(uint256 liquidity) external returns (uint256 baseShare, uint256 quoteBalance);

    // getters

    function symbol() external view returns (string memory);

    function exchange() external view returns (address);

    function previewSwap(
        bool isBaseToQuote,
        bool isExactInput,
        uint256 amount,
        bool isLiquidation
    ) external view returns (uint256);

    function maxSwap(
        bool isBaseToQuote,
        bool isExactInput,
        bool isLiquidation
    ) external view returns (uint256 amount);

    function getMarkPriceX96() external view returns (uint256);

    function getShareMarkPriceX96() external view returns (uint256);

    function getLiquidityValue(uint256 liquidity) external view returns (uint256 baseShare, uint256 quoteBalance);

    function getLiquidityDeleveraged(
        uint256 liquidity,
        uint256 cumDeleveragedBasePerLiquidityX96,
        uint256 cumDeleveragedQuotePerLiquidityX96
    ) external view returns (uint256, uint256);

    function getCumDeleveragedPerLiquidityX96() external view returns (uint256, uint256);

    function baseBalancePerShareX96() external view returns (uint256);
}
