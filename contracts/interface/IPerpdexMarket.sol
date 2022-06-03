// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.7.6;
pragma abicoder v2;

interface IPerpdexMarket {
    event FundingPaid(int256 fundingRateX96);
    event Swapped(bool isBaseToQuote, bool isExactInput, uint256 amount, uint256 oppositeAmount);

    function swap(
        bool isBaseToQuote,
        bool isExactInput,
        uint256 amount
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

    function swapDry(
        bool isBaseToQuote,
        bool isExactInput,
        uint256 amount
    ) external view returns (uint256);

    function getMarkPriceX96() external view returns (uint256);

    function getShareMarkPriceX96() external view returns (uint256);

    function getLiquidityValue(uint256 liquidity) external view returns (uint256 baseShare, uint256 quoteBalance);

    function getLiquidityDeleveraged(
        uint256 liquidity,
        uint256 cumDeleveragedBasePerLiquidity,
        uint256 cumDeleveragedQuotePerLiquidity
    ) external view returns (uint256, uint256);

    function getCumDeleveragedPerLiquidity() external view returns (uint256, uint256);

    function baseBalancePerShare() external view returns (uint256);
}
