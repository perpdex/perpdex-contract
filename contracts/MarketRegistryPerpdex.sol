// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { AddressUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import { IERC20Metadata } from "./interface/IERC20Metadata.sol";
import { ClearingHouseCallee } from "./base/ClearingHouseCallee.sol";
import { IVirtualToken } from "./interface/IVirtualToken.sol";
import { MarketRegistryPerpdexStorageV1 } from "./storage/MarketRegistryPerpdexStorage.sol";
import { IMarketRegistryPerpdex } from "./interface/IMarketRegistryPerpdex.sol";
import { IUniswapV2Factory } from "./amm/uniswap_v2/interfaces/IUniswapV2Factory.sol";

// never inherit any new stateful contract. never change the orders of parent stateful contracts
contract MarketRegistryPerpdex is IMarketRegistryPerpdex, ClearingHouseCallee, MarketRegistryPerpdexStorageV1 {
    using AddressUpgradeable for address;

    //
    // MODIFIER
    //

    //
    // EXTERNAL NON-VIEW
    //

    function initialize(address uniswapV2FactoryArg, address quoteTokenArg) external initializer {
        __ClearingHouseCallee_init();

        // UniswapV2Factory is not contract
        require(uniswapV2FactoryArg.isContract(), "MR_UFNC");
        // QuoteToken is not contract
        require(quoteTokenArg.isContract(), "MR_QTNC");

        // update states
        _uniswapV2Factory = uniswapV2FactoryArg;
        _quoteToken = quoteTokenArg;
    }

    //
    // EXTERNAL VIEW
    //

    /// @inheritdoc IMarketRegistryPerpdex
    function getQuoteToken() external view override returns (address) {
        return _quoteToken;
    }

    /// @inheritdoc IMarketRegistryPerpdex
    function getUniswapV2Factory() external view override returns (address) {
        return _uniswapV2Factory;
    }

    /// @inheritdoc IMarketRegistryPerpdex
    function hasPool(address baseToken) external view override returns (bool) {
        return IUniswapV2Factory(_uniswapV2Factory).getPair(baseToken, _quoteToken) != address(0);
    }
}
