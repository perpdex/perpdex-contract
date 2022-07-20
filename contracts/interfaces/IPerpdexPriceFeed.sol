// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.7.6;

interface IPerpdexPriceFeed {
    function decimals() external view returns (uint8);

    /// @dev Returns the index price of the token.
    function getPrice() external view returns (uint256);
}
