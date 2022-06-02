// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.7.6;
pragma abicoder v2;

interface IPerpdexMarket {
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

    function getMarkPriceX96() external view returns (uint256);

    function getLiquidityValue(uint256 liquidity) external view returns (uint256 baseShare, uint256 quoteBalance);

    function shareToBalance(uint256 baseShare) external view returns (uint256);

    function balanceToShare(uint256 baseBalance) external view returns (uint256);
}
