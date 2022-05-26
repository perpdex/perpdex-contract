// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.7.6;
pragma abicoder v2;

import { PerpdexStructs } from "../lib/PerpdexStructs.sol";

interface IMarket {
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

    function removeLiquidity(uint256 liquidity) external returns (uint256, uint256);

    function rebase() external;

    function getMarkPriceX96() external view returns (uint256);

    function shareToBalance(uint256 share) external view returns (uint256);

    function balanceToShare(uint256 balance) external view returns (uint256);
}
