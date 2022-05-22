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
        require(!AccountLibrary.isLiquidatable(accountInfo));

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

        PerpdexStructs.OrderInfo storage orderInfo = accountInfo.orderInfo[params.baseToken];
        orderInfo.baseDebtShare = orderInfo.baseDebtShare.add(
            IBaseTokenNew(params.baseToken).balanceToShare(response.base)
        );
        orderInfo.quoteDebt = orderInfo.quoteDebt.add(response.quote);
        orderInfo.liquidity = orderInfo.liquidity.add(response.liquidity);

        require(AccountLibrary.hasEnoughInitialMargin(accountInfo));

        return AddLiquidityResponse({ base: response.base, quote: response.quote, liquidity: response.liquidity });
    }

    function removeLiquidity(PerpdexStructs.AccountInfo storage accountInfo, RemoveLiquidityParams calldata params)
        public
        checkDeadline(params.deadline)
        returns (RemoveLiquidityResponse memory)
    {
        if (!params.makerIsSender) {
            require(AccountLibrary.isLiquidatable(accountInfo));
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
            _removeLiquidityFromOrder(accountInfo.orderInfo[params.baseToken], params.liquidity);

        int256 takerBase =
            response.base.toInt256().sub(IBaseTokenNew(params.baseToken).shareToBalance(baseDebtShare).toInt256());
        int256 takerQuote = response.quote.toInt256().sub(quoteDebt.toInt256());
        TakerLibrary.addToTakerBalance(
            accountInfo.takerInfo[params.baseToken],
            params.baseToken,
            takerBase,
            takerQuote
        );

        return
            RemoveLiquidityResponse({
                base: response.base,
                quote: response.quote,
                takerBase: takerBase,
                takerQuote: takerQuote,
                realizedPnL: 0, // TODO: implement
                priceAfterX96: UniswapV2Broker.getMarkPriceX96(params.poolFactory, params.baseToken, params.quoteToken)
            });
    }

    function _removeLiquidityFromOrder(PerpdexStructs.OrderInfo storage orderInfo, uint256 liquidity)
        internal
        returns (uint256 baseDebtShare, uint256 quoteDebt)
    {
        if (liquidity != 0) {
            if (orderInfo.baseDebtShare != 0) {
                baseDebtShare = FullMath.mulDiv(orderInfo.baseDebtShare, liquidity, orderInfo.liquidity);
                orderInfo.baseDebtShare = orderInfo.baseDebtShare.sub(baseDebtShare);
            }
            if (orderInfo.quoteDebt != 0) {
                quoteDebt = FullMath.mulDiv(orderInfo.quoteDebt, liquidity, orderInfo.liquidity);
                orderInfo.quoteDebt = orderInfo.quoteDebt.sub(quoteDebt);
            }
            orderInfo.liquidity = orderInfo.liquidity.sub(liquidity);
        }

        return (baseDebtShare, quoteDebt);
    }
}
