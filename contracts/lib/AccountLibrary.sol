// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import { FixedPoint96 } from "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";
import { PerpMath } from "./PerpMath.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { SignedSafeMath } from "@openzeppelin/contracts/math/SignedSafeMath.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { PerpSafeCast } from "./PerpSafeCast.sol";
import { IPerpdexMarket } from "../interface/IPerpdexMarket.sol";
import { PerpdexStructs } from "./PerpdexStructs.sol";

// https://help.ftx.com/hc/en-us/articles/360024780511-Complete-Futures-Specs
library AccountLibrary {
    using PerpMath for int256;
    using PerpMath for uint256;
    using PerpSafeCast for uint256;
    using SafeMath for uint256;
    using SignedSafeMath for int256;

    function getTotalAccountValue(PerpdexStructs.AccountInfo storage accountInfo) internal view returns (int256) {
        address[] storage markets = accountInfo.markets;
        int256 accountValue = accountInfo.vaultInfo.collateralBalance;
        uint256 length = markets.length;
        for (uint256 i = 0; i < length; ++i) {
            address market = markets[i];

            PerpdexStructs.MakerInfo storage makerInfo = accountInfo.makerInfos[market];
            int256 baseShare = accountInfo.takerInfos[market].baseBalanceShare.sub(makerInfo.baseDebtShare.toInt256());
            int256 quoteBalance = accountInfo.takerInfos[market].quoteBalance.sub(makerInfo.quoteDebt.toInt256());
            (uint256 poolBaseShare, uint256 poolQuoteBalance) =
                IPerpdexMarket(market).getLiquidityValue(makerInfo.liquidity);
            (uint256 deleveragedBaseShare, uint256 deleveragedQuoteBalance) =
                IPerpdexMarket(market).getLiquidityDeleveraged(
                    makerInfo.liquidity,
                    makerInfo.cumDeleveragedBaseSharePerLiquidity,
                    makerInfo.cumDeleveragedQuotePerLiquidity
                );

            int256 positionShare = baseShare.add(poolBaseShare.add(deleveragedBaseShare).toInt256());
            uint256 sharePriceX96 = IPerpdexMarket(market).getShareMarkPriceX96();

            accountValue = accountValue.add(positionShare.mulDiv(sharePriceX96.toInt256(), FixedPoint96.Q96));
            accountValue = accountValue.add(quoteBalance.add(poolQuoteBalance.add(deleveragedQuoteBalance).toInt256()));
        }
        return accountValue;
    }

    function getPositionShare(PerpdexStructs.AccountInfo storage accountInfo, address market)
        internal
        view
        returns (int256)
    {
        PerpdexStructs.MakerInfo storage makerInfo = accountInfo.makerInfos[market];
        int256 baseShare = accountInfo.takerInfos[market].baseBalanceShare.sub(makerInfo.baseDebtShare.toInt256());
        (uint256 poolBaseShare, ) = IPerpdexMarket(market).getLiquidityValue(makerInfo.liquidity);
        (uint256 deleveragedBaseShare, ) =
            IPerpdexMarket(market).getLiquidityDeleveraged(
                makerInfo.liquidity,
                makerInfo.cumDeleveragedBaseSharePerLiquidity,
                makerInfo.cumDeleveragedQuotePerLiquidity
            );
        return baseShare.add(poolBaseShare.add(deleveragedBaseShare).toInt256());
    }

    function getPositionNotional(PerpdexStructs.AccountInfo storage accountInfo, address market)
        internal
        view
        returns (int256)
    {
        int256 positionShare = getPositionShare(accountInfo, market);
        uint256 sharePriceX96 = IPerpdexMarket(market).getShareMarkPriceX96();
        return positionShare.mulDiv(sharePriceX96.toInt256(), FixedPoint96.Q96);
    }

    function getTotalPositionNotional(PerpdexStructs.AccountInfo storage accountInfo) internal view returns (uint256) {
        address[] storage markets = accountInfo.markets;
        uint256 totalPositionNotional;
        uint256 length = markets.length;
        for (uint256 i = 0; i < length; ++i) {
            uint256 positionNotional = getPositionNotional(accountInfo, markets[i]).abs();
            totalPositionNotional = totalPositionNotional.add(positionNotional);
        }
        return totalPositionNotional;
    }

    function getOpenPositionShare(PerpdexStructs.AccountInfo storage accountInfo, address market)
        internal
        view
        returns (uint256)
    {
        PerpdexStructs.MakerInfo storage makerInfo = accountInfo.makerInfos[market];
        (uint256 poolBaseShare, ) = IPerpdexMarket(market).getLiquidityValue(makerInfo.liquidity);
        return getPositionShare(accountInfo, market).abs().add(poolBaseShare);
    }

    function getOpenPositionNotional(PerpdexStructs.AccountInfo storage accountInfo, address market)
        internal
        view
        returns (uint256)
    {
        uint256 positionShare = getOpenPositionShare(accountInfo, market);
        uint256 sharePriceX96 = IPerpdexMarket(market).getShareMarkPriceX96();
        return FullMath.mulDiv(positionShare, sharePriceX96, FixedPoint96.Q96);
    }

    function getTotalOpenPositionNotional(PerpdexStructs.AccountInfo storage accountInfo)
        internal
        view
        returns (uint256)
    {
        address[] storage markets = accountInfo.markets;
        uint256 totalOpenPositionNotional;
        uint256 length = markets.length;
        for (uint256 i = 0; i < length; ++i) {
            uint256 positionNotional = getOpenPositionNotional(accountInfo, markets[i]);
            totalOpenPositionNotional = totalOpenPositionNotional.add(positionNotional);
        }
        return totalOpenPositionNotional;
    }

    // always true when hasEnoughMaintenanceMargin is true
    function hasEnoughMaintenanceMargin(PerpdexStructs.AccountInfo storage accountInfo, uint24 mmRatio)
        internal
        view
        returns (bool)
    {
        int256 accountValue = getTotalAccountValue(accountInfo);
        uint256 totalPositionNotional = getTotalPositionNotional(accountInfo);
        return accountValue >= totalPositionNotional.mulRatio(mmRatio).toInt256();
    }

    function hasEnoughInitialMargin(PerpdexStructs.AccountInfo storage accountInfo, uint24 imRatio)
        internal
        view
        returns (bool)
    {
        int256 accountValue = getTotalAccountValue(accountInfo);
        uint256 totalOpenPositionNotional = getTotalOpenPositionNotional(accountInfo);
        return
            accountValue.min(accountInfo.vaultInfo.collateralBalance) >=
            totalOpenPositionNotional.mulRatio(imRatio).toInt256();
    }

    function updateMarkets(
        PerpdexStructs.AccountInfo storage accountInfo,
        address market,
        uint8 maxMarketsPerAccount
    ) internal {
        require(market != address(0));

        bool enabled =
            accountInfo.takerInfos[market].baseBalanceShare != 0 || accountInfo.makerInfos[market].liquidity != 0;
        address[] storage markets = accountInfo.markets;
        uint256 length = markets.length;
        for (uint256 i = 0; i < length; ++i) {
            if (markets[i] == market) {
                if (!enabled) {
                    markets[i] = markets[length - 1];
                    markets.pop();
                }
                return;
            }
        }
        markets.push(market);
        require(markets.length <= maxMarketsPerAccount);
    }
}
