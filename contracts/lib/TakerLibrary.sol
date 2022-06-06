// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { SignedSafeMath } from "@openzeppelin/contracts/math/SignedSafeMath.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { PerpMath } from "./PerpMath.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/SafeCast.sol";
import { IPerpdexMarket } from "../interface/IPerpdexMarket.sol";
import { PerpdexStructs } from "./PerpdexStructs.sol";
import { AccountLibrary } from "./AccountLibrary.sol";
import { PriceLimitLibrary } from "./PriceLimitLibrary.sol";

library TakerLibrary {
    using PerpMath for int256;
    using PerpMath for uint256;
    using SafeCast for uint256;
    using SafeMath for uint256;
    using SignedSafeMath for int256;

    struct OpenPositionParams {
        address market;
        bool isBaseToQuote;
        bool isExactInput;
        uint256 amount;
        uint256 oppositeAmountBound;
        PerpdexStructs.PriceLimitConfig priceLimitConfig;
        bool isMarketAllowed;
        uint24 mmRatio;
        uint24 imRatio;
        uint8 maxMarketsPerAccount;
        uint24 protocolFeeRatio;
        uint24 liquidationRewardRatio;
        bool isSelf;
    }

    struct OpenPositionDryParams {
        address market;
        bool isBaseToQuote;
        bool isExactInput;
        uint256 amount;
        uint256 oppositeAmountBound;
        uint24 mmRatio;
        uint24 protocolFeeRatio;
        bool isSelf;
    }

    struct OpenPositionResponse {
        int256 base;
        int256 quote;
        int256 realizedPnl;
        uint256 protocolFee;
        uint256 priceAfterX96;
        uint256 liquidationReward;
        uint256 insuranceFundReward;
        bool isLiquidation;
    }

    function openPosition(
        PerpdexStructs.AccountInfo storage accountInfo,
        PerpdexStructs.VaultInfo storage liquidatorVaultInfo,
        PerpdexStructs.InsuranceFundInfo storage insuranceFundInfo,
        PerpdexStructs.PriceLimitInfo storage priceLimitInfo,
        PerpdexStructs.ProtocolInfo storage protocolInfo,
        OpenPositionParams memory params
    ) internal returns (OpenPositionResponse memory response) {
        response.isLiquidation = !AccountLibrary.hasEnoughMaintenanceMargin(accountInfo, params.mmRatio);

        if (!params.isSelf) {
            require(response.isLiquidation, "TL_OP: enough mm");
        }

        {
            uint256 priceBeforeX96 = IPerpdexMarket(params.market).getMarkPriceX96();
            PriceLimitLibrary.update(priceLimitInfo, priceBeforeX96);
        }

        int256 takerBaseBefore = accountInfo.takerInfos[params.market].baseBalanceShare;

        (response.base, response.quote, response.realizedPnl, response.protocolFee) = _doSwap(
            accountInfo,
            protocolInfo,
            params.market,
            params.isBaseToQuote,
            params.isExactInput,
            params.amount,
            params.oppositeAmountBound,
            params.maxMarketsPerAccount,
            params.protocolFeeRatio
        );

        bool isOpen = (takerBaseBefore.add(response.base)).sign() * response.base.sign() > 0;

        if (!params.isMarketAllowed) {
            require(!isOpen, "TL_OP: no open when closed");
        }

        if (response.isLiquidation) {
            require(!isOpen, "TL_OP: no open when liquidation");

            processLiquidationFee(
                accountInfo.vaultInfo,
                liquidatorVaultInfo,
                insuranceFundInfo,
                params.mmRatio,
                params.liquidationRewardRatio,
                response.quote.abs()
            );
        }

        response.priceAfterX96 = IPerpdexMarket(params.market).getMarkPriceX96();
        if (response.isLiquidation) {
            require(
                PriceLimitLibrary.isLiquidationAllowed(priceLimitInfo, params.priceLimitConfig, response.priceAfterX96),
                "TL_OP: liquidation price limit"
            );
        } else {
            require(
                PriceLimitLibrary.isNormalOrderAllowed(priceLimitInfo, params.priceLimitConfig, response.priceAfterX96),
                "TL_OP: normal order price limit"
            );
        }

        if (isOpen) {
            require(AccountLibrary.hasEnoughInitialMargin(accountInfo, params.imRatio), "TL_OP: not enough im");
        }
    }

    function addToTakerBalance(
        PerpdexStructs.AccountInfo storage accountInfo,
        address market,
        int256 baseShare,
        int256 quoteBalance,
        int256 quoteFee,
        uint8 maxMarketsPerAccount
    ) internal returns (int256 realizedPnl) {
        require(baseShare.sign() * quoteBalance.sign() == -1, "TL_ATTB: invalid input");

        PerpdexStructs.TakerInfo storage takerInfo = accountInfo.takerInfos[market];

        if (takerInfo.baseBalanceShare.sign() * baseShare.sign() == -1) {
            uint256 FULLY_CLOSED_RATIO = 1e18;
            uint256 closedRatio =
                FullMath.mulDiv(baseShare.abs(), FULLY_CLOSED_RATIO, takerInfo.baseBalanceShare.abs());

            if (closedRatio <= FULLY_CLOSED_RATIO) {
                int256 reducedOpenNotional = takerInfo.quoteBalance.mulDiv(closedRatio.toInt256(), FULLY_CLOSED_RATIO);
                realizedPnl = quoteBalance.add(reducedOpenNotional);
            } else {
                int256 closedPositionNotional = quoteBalance.mulDiv(int256(FULLY_CLOSED_RATIO), closedRatio);
                realizedPnl = takerInfo.quoteBalance.add(closedPositionNotional);
            }
        }
        realizedPnl = realizedPnl.add(quoteFee);

        takerInfo.baseBalanceShare = takerInfo.baseBalanceShare.add(baseShare);
        takerInfo.quoteBalance = takerInfo.quoteBalance.add(quoteBalance).add(quoteFee).sub(realizedPnl);
        accountInfo.vaultInfo.collateralBalance = accountInfo.vaultInfo.collateralBalance.add(realizedPnl);

        AccountLibrary.updateMarkets(accountInfo, market, maxMarketsPerAccount);
    }

    // Even if openPosition reverts, it may not revert.
    // Attempting to match reverts makes the implementation too complicated
    function openPositionDry(PerpdexStructs.AccountInfo storage accountInfo, OpenPositionDryParams memory params)
        internal
        view
        returns (int256 base, int256 quote)
    {
        bool isLiquidation = !AccountLibrary.hasEnoughMaintenanceMargin(accountInfo, params.mmRatio);

        if (!isLiquidation) {
            require(params.isSelf, "TL_OPD: not self");
        }

        (uint256 oppositeAmount, ) =
            swapWithProtocolFeeDry(
                params.market,
                params.isBaseToQuote,
                params.isExactInput,
                params.amount,
                params.protocolFeeRatio
            );
        validateSlippage(params.isExactInput, oppositeAmount, params.oppositeAmountBound);
        (base, quote) = swapResponseToBaseQuote(
            params.isBaseToQuote,
            params.isExactInput,
            params.amount,
            oppositeAmount
        );
    }

    function _doSwap(
        PerpdexStructs.AccountInfo storage accountInfo,
        PerpdexStructs.ProtocolInfo storage protocolInfo,
        address market,
        bool isBaseToQuote,
        bool isExactInput,
        uint256 amount,
        uint256 oppositeAmountBound,
        uint8 maxMarketsPerAccount,
        uint24 protocolFeeRatio
    )
        private
        returns (
            int256 base,
            int256 quote,
            int256 realizedPnl,
            uint256 protocolFee
        )
    {
        uint256 oppositeAmount;

        if (protocolFeeRatio > 0) {
            (oppositeAmount, protocolFee) = swapWithProtocolFee(
                protocolInfo,
                market,
                isBaseToQuote,
                isExactInput,
                amount,
                protocolFeeRatio
            );
        } else {
            oppositeAmount = IPerpdexMarket(market).swap(isBaseToQuote, isExactInput, amount);
        }
        validateSlippage(isExactInput, oppositeAmount, oppositeAmountBound);

        (base, quote) = swapResponseToBaseQuote(isBaseToQuote, isExactInput, amount, oppositeAmount);
        realizedPnl = addToTakerBalance(accountInfo, market, base, quote, 0, maxMarketsPerAccount);
    }

    function swapWithProtocolFee(
        PerpdexStructs.ProtocolInfo storage protocolInfo,
        address market,
        bool isBaseToQuote,
        bool isExactInput,
        uint256 amount,
        uint24 protocolFeeRatio
    ) internal returns (uint256 oppositeAmount, uint256 protocolFee) {
        if (isExactInput) {
            if (isBaseToQuote) {
                oppositeAmount = IPerpdexMarket(market).swap(isBaseToQuote, isExactInput, amount);
                protocolFee = oppositeAmount.mulRatio(protocolFeeRatio);
                oppositeAmount = oppositeAmount.sub(protocolFee);
            } else {
                protocolFee = amount.mulRatio(protocolFeeRatio);
                oppositeAmount = IPerpdexMarket(market).swap(isBaseToQuote, isExactInput, amount.sub(protocolFee));
            }
        } else {
            if (isBaseToQuote) {
                protocolFee = amount.divRatio(PerpMath.subRatio(1e6, protocolFeeRatio)).sub(amount);
                oppositeAmount = IPerpdexMarket(market).swap(isBaseToQuote, isExactInput, amount.add(protocolFee));
            } else {
                uint256 oppositeAmountWithoutFee = IPerpdexMarket(market).swap(isBaseToQuote, isExactInput, amount);
                oppositeAmount = oppositeAmountWithoutFee.divRatio(PerpMath.subRatio(1e6, protocolFeeRatio));
                protocolFee = oppositeAmount.sub(oppositeAmountWithoutFee);
            }
        }

        protocolInfo.protocolFee = protocolInfo.protocolFee.add(protocolFee);
    }

    function processLiquidationFee(
        PerpdexStructs.VaultInfo storage vaultInfo,
        PerpdexStructs.VaultInfo storage liquidatorVaultInfo,
        PerpdexStructs.InsuranceFundInfo storage insuranceFundInfo,
        uint24 mmRatio,
        uint24 liquidatorRewardRatio,
        uint256 exchangedQuote
    ) internal returns (uint256 liquidatorReward, uint256 insuranceFundReward) {
        uint256 penalty = exchangedQuote.mulRatio(mmRatio);
        liquidatorReward = penalty.mulRatio(liquidatorRewardRatio);
        insuranceFundReward = penalty.sub(liquidatorReward);

        vaultInfo.collateralBalance = vaultInfo.collateralBalance.sub(penalty.toInt256());
        liquidatorVaultInfo.collateralBalance = liquidatorVaultInfo.collateralBalance.add(liquidatorReward.toInt256());
        insuranceFundInfo.balance = insuranceFundInfo.balance.add(insuranceFundReward.toInt256());
    }

    function swapWithProtocolFeeDry(
        address market,
        bool isBaseToQuote,
        bool isExactInput,
        uint256 amount,
        uint24 protocolFeeRatio
    ) internal view returns (uint256 oppositeAmount, uint256 protocolFee) {
        if (isExactInput) {
            if (isBaseToQuote) {
                oppositeAmount = IPerpdexMarket(market).swapDry(isBaseToQuote, isExactInput, amount);
                protocolFee = oppositeAmount.mulRatio(protocolFeeRatio);
                oppositeAmount = oppositeAmount.sub(protocolFee);
            } else {
                protocolFee = amount.mulRatio(protocolFeeRatio);
                oppositeAmount = IPerpdexMarket(market).swapDry(isBaseToQuote, isExactInput, amount.sub(protocolFee));
            }
        } else {
            if (isBaseToQuote) {
                protocolFee = amount.divRatio(PerpMath.subRatio(1e6, protocolFeeRatio)).sub(amount);
                oppositeAmount = IPerpdexMarket(market).swapDry(isBaseToQuote, isExactInput, amount.add(protocolFee));
            } else {
                uint256 oppositeAmountWithoutFee = IPerpdexMarket(market).swapDry(isBaseToQuote, isExactInput, amount);
                oppositeAmount = oppositeAmountWithoutFee.divRatio(PerpMath.subRatio(1e6, protocolFeeRatio));
                protocolFee = oppositeAmount.sub(oppositeAmountWithoutFee);
            }
        }
    }

    function validateSlippage(
        bool isExactInput,
        uint256 oppositeAmount,
        uint256 oppositeAmountBound
    ) internal pure {
        if (isExactInput) {
            require(oppositeAmount >= oppositeAmountBound, "TL_VS: too small opposite amount");
        } else {
            require(oppositeAmount <= oppositeAmountBound, "TL_VS: too large opposite amount");
        }
    }

    function swapResponseToBaseQuote(
        bool isBaseToQuote,
        bool isExactInput,
        uint256 amount,
        uint256 oppositeAmount
    ) internal pure returns (int256, int256) {
        if (isExactInput) {
            if (isBaseToQuote) {
                return (amount.neg256(), oppositeAmount.toInt256());
            } else {
                return (oppositeAmount.toInt256(), amount.neg256());
            }
        } else {
            if (isBaseToQuote) {
                return (oppositeAmount.neg256(), amount.toInt256());
            } else {
                return (amount.toInt256(), oppositeAmount.neg256());
            }
        }
    }
}
