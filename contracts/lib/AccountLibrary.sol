// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import { FixedPoint96 } from "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";
import { PerpMath } from "./PerpMath.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { SignedSafeMath } from "@openzeppelin/contracts/math/SignedSafeMath.sol";
import { FullMath } from "@uniswap/lib/contracts/libraries/FullMath.sol";
import { PerpSafeCast } from "./PerpSafeCast.sol";
import { UniswapV2Broker } from "./UniswapV2Broker.sol";
import { BaseTokenLibrary } from "./BaseTokenLibrary.sol";
import "./PerpdexStructs.sol";

// https://help.ftx.com/hc/en-us/articles/360024780511-Complete-Futures-Specs
library AccountLibrary {
    using PerpMath for int256;
    using PerpMath for uint256;
    using PerpSafeCast for uint256;
    using SafeMath for uint256;
    using SignedSafeMath for int256;

    function getTotalAccountValue(
        PerpdexStructs.AccountInfo storage accountInfo,
        address poolFactory,
        address quoteToken
    ) public view returns (int256) {
        address[] storage baseTokens = accountInfo.baseTokens;
        int256 accountValue = accountInfo.vaultInfo.collateralBalance;
        uint256 length = baseTokens.length;
        for (uint256 i = 0; i < length; ++i) {
            accountValue = accountValue.add(getPositionNotional(accountInfo, poolFactory, baseTokens[i], quoteToken));
            // TODO: implement
            //            accountValue = accountValue.add(getPositionNotional(accountInfo, baseTokens[i]));
        }
        return accountValue;
    }

    function getPositionSize(
        PerpdexStructs.AccountInfo storage accountInfo,
        address poolFactory,
        address baseToken,
        address quoteToken
    ) public view returns (int256) {
        PerpdexStructs.MakerInfo storage makerInfo = accountInfo.makerInfo[baseToken];
        int256 baseShare = accountInfo.takerInfo[baseToken].baseBalanceShare.sub(makerInfo.baseDebtShare.toInt256());
        (uint256 basePool, uint256 quotePool) =
            UniswapV2Broker.getLiquidityValue(poolFactory, baseToken, quoteToken, makerInfo.liquidity);
        return BaseTokenLibrary.shareToBalance(baseToken, baseShare).add(basePool.toInt256());
    }

    function getPositionNotional(
        PerpdexStructs.AccountInfo storage accountInfo,
        address poolFactory,
        address baseToken,
        address quoteToken
    ) public view returns (int256) {
        int256 positionSize = getPositionSize(accountInfo, poolFactory, baseToken, quoteToken);
        uint256 priceX96 = UniswapV2Broker.getMarkPriceX96(poolFactory, baseToken, quoteToken);
        return positionSize.mulDiv(priceX96.toInt256(), FixedPoint96.Q96);
    }

    function getTotalPositionNotional(
        PerpdexStructs.AccountInfo storage accountInfo,
        address poolFactory,
        address quoteToken
    ) public view returns (uint256) {
        address[] storage baseTokens = accountInfo.baseTokens;
        uint256 totalPositionNotional;
        uint256 length = baseTokens.length;
        for (uint256 i = 0; i < length; ++i) {
            uint256 positionNotional = getPositionNotional(accountInfo, poolFactory, baseTokens[i], quoteToken).abs();
            totalPositionNotional = totalPositionNotional.add(positionNotional);
        }
        return totalPositionNotional;
    }

    function getOpenPositionSize(
        PerpdexStructs.AccountInfo storage accountInfo,
        address poolFactory,
        address baseToken,
        address quoteToken
    ) public view returns (uint256) {
        PerpdexStructs.MakerInfo storage makerInfo = accountInfo.makerInfo[baseToken];
        (uint256 basePool, uint256 quotePool) =
            UniswapV2Broker.getLiquidityValue(poolFactory, baseToken, quoteToken, makerInfo.liquidity);
        return getPositionSize(accountInfo, poolFactory, baseToken, quoteToken).abs().add(basePool);
    }

    function getOpenPositionNotional(
        PerpdexStructs.AccountInfo storage accountInfo,
        address poolFactory,
        address baseToken,
        address quoteToken
    ) public view returns (uint256) {
        uint256 positionSize = getOpenPositionSize(accountInfo, poolFactory, baseToken, quoteToken);
        uint256 priceX96 = UniswapV2Broker.getMarkPriceX96(poolFactory, baseToken, quoteToken);
        return FullMath.mulDiv(positionSize, priceX96, FixedPoint96.Q96);
    }

    function getTotalOpenPositionNotional(
        PerpdexStructs.AccountInfo storage accountInfo,
        address poolFactory,
        address quoteToken
    ) public view returns (uint256) {
        address[] storage baseTokens = accountInfo.baseTokens;
        uint256 totalOpenPositionNotional;
        uint256 length = baseTokens.length;
        for (uint256 i = 0; i < length; ++i) {
            uint256 positionNotional = getOpenPositionNotional(accountInfo, poolFactory, baseTokens[i], quoteToken);
            totalOpenPositionNotional = totalOpenPositionNotional.add(positionNotional);
        }
        return totalOpenPositionNotional;
    }

    // always true when hasEnoughMaintenanceMargin is true
    function hasEnoughMaintenanceMargin(
        PerpdexStructs.AccountInfo storage accountInfo,
        address poolFactory,
        address quoteToken,
        uint24 mmRatio
    ) public view returns (bool) {
        int256 accountValue = getTotalAccountValue(accountInfo, poolFactory, quoteToken);
        uint256 totalPositionNotional = getTotalPositionNotional(accountInfo, poolFactory, quoteToken);
        return accountValue >= totalPositionNotional.mulRatio(mmRatio).toInt256();
    }

    function hasEnoughInitialMargin(
        PerpdexStructs.AccountInfo storage accountInfo,
        address poolFactory,
        address quoteToken,
        uint24 imRatio
    ) public view returns (bool) {
        int256 accountValue = getTotalAccountValue(accountInfo, poolFactory, quoteToken);
        uint256 totalOpenPositionNotional = getTotalOpenPositionNotional(accountInfo, poolFactory, quoteToken);
        return
            accountValue.min(accountInfo.vaultInfo.collateralBalance) >=
            totalOpenPositionNotional.mulRatio(imRatio).toInt256();
    }

    function updateBaseTokens(
        PerpdexStructs.AccountInfo storage accountInfo,
        address baseToken,
        uint8 maxMarketsPerAccount
    ) public {
        bool enabled =
            accountInfo.takerInfo[baseToken].baseBalanceShare != 0 || accountInfo.makerInfo[baseToken].liquidity != 0;
        address[] storage baseTokens = accountInfo.baseTokens;
        uint256 length = baseTokens.length;
        for (uint256 i = 0; i < length; ++i) {
            if (baseTokens[i] == baseToken) {
                if (!enabled) {
                    baseTokens[i] = baseTokens[length - 1];
                    baseTokens.pop();
                }
                return;
            }
        }
        baseTokens.push(baseToken);
        require(baseTokens.length <= maxMarketsPerAccount);
    }
}
