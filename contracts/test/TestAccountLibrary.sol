// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { AccountLibrary } from "../lib/AccountLibrary.sol";
import { PerpdexStructs } from "../lib/PerpdexStructs.sol";

contract TestAccountLibrary {
    constructor() {}

    PerpdexStructs.AccountInfo public accountInfo;

    function updateMarkets(address market, uint8 maxMarketsPerAccount) external {
        AccountLibrary.updateMarkets(accountInfo, market, maxMarketsPerAccount);
    }

    function setMarkets(address[] memory markets) external {
        accountInfo.markets = markets;
    }

    function setTakerInfo(address market, PerpdexStructs.TakerInfo memory takerInfo) external {
        accountInfo.takerInfos[market] = takerInfo;
    }

    function setMakerInfo(address market, PerpdexStructs.MakerInfo memory makerInfo) external {
        accountInfo.makerInfos[market] = makerInfo;
    }

    function getMarkets() external view returns (address[] memory) {
        return accountInfo.markets;
    }
}
