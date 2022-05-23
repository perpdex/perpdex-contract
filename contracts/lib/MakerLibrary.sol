// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { UniswapV2Broker } from "./UniswapV2Broker.sol";
import "./PerpdexStructs.sol";
import "./TakerLibrary.sol";

library MakerLibrary {
    using PerpSafeCast for uint256;
    using SafeMath for uint256;
    using SignedSafeMath for int256;

    struct AddLiquidityParams {
        address baseToken;
        address quoteToken;
        uint256 base;
        uint256 quote;
        uint256 minBase;
        uint256 minQuote;
        uint256 deadline;
        address poolFactory;
        bool isBaseTokenAllowed;
        uint24 imRatio;
    }

    struct AddLiquidityResponse {
        uint256 base;
        uint256 quote;
        uint256 liquidity;
    }

    struct RemoveLiquidityParams {
        address baseToken;
        address quoteToken;
        uint256 liquidity;
        uint256 minBase;
        uint256 minQuote;
        uint256 deadline;
        address poolFactory;
        bool makerIsSender;
        uint24 mmRatio;
    }

    struct RemoveLiquidityResponse {
        uint256 base;
        uint256 quote;
        int256 takerBase;
        int256 takerQuote;
        int256 realizedPnL;
        uint256 priceAfterX96;
    }

    modifier checkDeadline(uint256 deadline) {
        require(block.timestamp <= deadline, "CH_TE");
        _;
    }

    function addLiquidity(PerpdexStructs.AccountInfo storage accountInfo, AddLiquidityParams calldata params)
        public
        checkDeadline(params.deadline)
        returns (AddLiquidityResponse memory)
    {
        require(params.isBaseTokenAllowed);

        UniswapV2Broker.AddLiquidityResponse memory response =
            UniswapV2Broker.addLiquidity(
                UniswapV2Broker.AddLiquidityParams(
                    params.poolFactory,
                    params.baseToken,
                    params.quoteToken,
                    params.base,
                    params.quote,
                    address(this)
                )
            );

        PerpdexStructs.MakerInfo storage makerInfo = accountInfo.makerInfo[params.baseToken];
        makerInfo.baseDebtShare = makerInfo.baseDebtShare.add(
            IBaseTokenNew(params.baseToken).balanceToShare(response.base)
        );
        makerInfo.quoteDebt = makerInfo.quoteDebt.add(response.quote);
        makerInfo.liquidity = makerInfo.liquidity.add(response.liquidity);

        AccountLibrary.updateBaseTokens(accountInfo, params.baseToken);

        require(
            AccountLibrary.hasEnoughInitialMargin(accountInfo, params.poolFactory, params.quoteToken, params.imRatio)
        );

        return AddLiquidityResponse({ base: response.base, quote: response.quote, liquidity: response.liquidity });
    }

    function removeLiquidity(PerpdexStructs.AccountInfo storage accountInfo, RemoveLiquidityParams calldata params)
        public
        checkDeadline(params.deadline)
        returns (RemoveLiquidityResponse memory)
    {
        if (!params.makerIsSender) {
            require(
                !AccountLibrary.hasEnoughMaintenanceMargin(
                    accountInfo,
                    params.poolFactory,
                    params.quoteToken,
                    params.mmRatio
                )
            );
        }

        UniswapV2Broker.RemoveLiquidityResponse memory response =
            UniswapV2Broker.removeLiquidity(
                UniswapV2Broker.RemoveLiquidityParams(
                    params.poolFactory,
                    params.baseToken,
                    params.quoteToken,
                    address(this),
                    params.liquidity
                )
            );

        // TODO: check slippage

        (uint256 baseDebtShare, uint256 quoteDebt) =
            _removeLiquidityFromOrder(accountInfo.makerInfo[params.baseToken], params.liquidity);
        AccountLibrary.updateBaseTokens(accountInfo, params.baseToken);

        int256 takerBase =
            response.base.toInt256().sub(IBaseTokenNew(params.baseToken).shareToBalance(baseDebtShare).toInt256());
        int256 takerQuote = response.quote.toInt256().sub(quoteDebt.toInt256());
        int256 realizedPnL = TakerLibrary.addToTakerBalance(accountInfo, params.baseToken, takerBase, takerQuote);

        return
            RemoveLiquidityResponse({
                base: response.base,
                quote: response.quote,
                takerBase: takerBase,
                takerQuote: takerQuote,
                realizedPnL: realizedPnL,
                priceAfterX96: UniswapV2Broker.getMarkPriceX96(params.poolFactory, params.baseToken, params.quoteToken)
            });
    }

    function _removeLiquidityFromOrder(PerpdexStructs.MakerInfo storage makerInfo, uint256 liquidity)
        internal
        returns (uint256 baseDebtShare, uint256 quoteDebt)
    {
        if (liquidity != 0) {
            if (makerInfo.baseDebtShare != 0) {
                baseDebtShare = FullMath.mulDiv(makerInfo.baseDebtShare, liquidity, makerInfo.liquidity);
                makerInfo.baseDebtShare = makerInfo.baseDebtShare.sub(baseDebtShare);
            }
            if (makerInfo.quoteDebt != 0) {
                quoteDebt = FullMath.mulDiv(makerInfo.quoteDebt, liquidity, makerInfo.liquidity);
                makerInfo.quoteDebt = makerInfo.quoteDebt.sub(quoteDebt);
            }
            makerInfo.liquidity = makerInfo.liquidity.sub(liquidity);
        }

        return (baseDebtShare, quoteDebt);
    }
}
