// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { PerpdexExchange } from "../PerpdexExchange.sol";

contract DebugPerpdexExchange is PerpdexExchange {
    uint256 private constant _RINKEBY_CHAIN_ID = 4;
    uint256 private constant _SHIBUYA_CHAIN_ID = 81;

    constructor(address settlementTokenArg) PerpdexExchange(settlementTokenArg) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        require(chainId == _RINKEBY_CHAIN_ID || chainId == _SHIBUYA_CHAIN_ID, "DPE_C: testnet only");
    }

    function setCollateralBalance(address trader, int256 balance) external {
        accountInfos[trader].vaultInfo.collateralBalance = balance;
    }
}
