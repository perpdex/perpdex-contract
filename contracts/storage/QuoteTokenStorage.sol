// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

/// @notice For future upgrades, do not change QuoteTokenStorageV1. Create a new
/// contract which implements QuoteTokenStorageV1 and following the naming convention
/// QuoteTokenStorageVX.
abstract contract QuoteTokenStorageV1 {
    // --------- IMMUTABLE ---------

    uint8 internal _priceFeedDecimals;

    // --------- ^^^^^^^^^ ---------

    address internal _priceFeed;
}
