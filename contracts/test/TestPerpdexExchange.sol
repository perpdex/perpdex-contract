// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { PerpdexExchange } from "../PerpdexExchange.sol";
import { PerpdexStructs } from "../lib/PerpdexStructs.sol";

contract TestPerpdexExchange is PerpdexExchange {
    constructor(address settlementTokenArg) PerpdexExchange(settlementTokenArg) {}

    function setAccountInfo(
        address trader,
        PerpdexStructs.VaultInfo memory vaultInfo,
        address[] memory markets
    ) external {
        accountInfos[trader].vaultInfo = vaultInfo;
        accountInfos[trader].markets = markets;
    }

    function setTakerInfo(
        address trader,
        address market,
        PerpdexStructs.TakerInfo memory takerInfo
    ) external {
        accountInfos[trader].takerInfos[market] = takerInfo;
    }

    function setMakerInfo(
        address trader,
        address market,
        PerpdexStructs.MakerInfo memory makerInfo
    ) external {
        accountInfos[trader].makerInfos[market] = makerInfo;
    }

    function setInsuranceFundInfo(PerpdexStructs.InsuranceFundInfo memory insuranceFundInfoArg) external {
        insuranceFundInfo = insuranceFundInfoArg;
    }

    function setProtocolInfo(PerpdexStructs.ProtocolInfo memory protocolInfoArg) external {
        protocolInfo = protocolInfoArg;
    }
}
