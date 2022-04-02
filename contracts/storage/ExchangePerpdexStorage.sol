// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import { Funding } from "../lib/Funding.sol";

/// @notice For future upgrades, do not change ExchangeStorageV1. Create a new
/// contract which implements ExchangeStorageV1 and following the naming convention
/// ExchangeStorageVX.
abstract contract ExchangePerpdexStorageV1 {
    address internal _orderBook;
    address internal _accountBalance;
    address internal _clearingHouseConfig;

    mapping(address => uint160) internal _lastUpdatedSqrtMarkPriceX96Map;
    mapping(address => uint256) internal _lastUpdatedSqrtMarkPriceX96TimestampMap;

    mapping(address => uint256) internal _firstTradedTimestampMap;
    mapping(address => uint256) internal _lastSettledTimestampMap;
    mapping(address => Funding.Growth) internal _globalFundingGrowthX96Map;

    // key: base token
    // value: a threshold to limit the price impact per block when reducing or closing the position
    mapping(address => uint256) internal _maxPriceRocX96WithinBlockMap;

    // first key: trader, second key: baseToken
    // value: the last timestamp when a trader exceeds price limit when closing a position/being liquidated
    //    mapping(address => mapping(address => uint256)) internal _lastOverPriceLimitTimestampMap;

    address internal _marketRegistry;

    // key: base token
    mapping(address => uint256) _lastPriceCumulativeMap;
    mapping(address => uint32) _lastPriceCumulativeTimestampMap;
}
