// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import { UniswapV2Broker } from "./UniswapV2Broker.sol";
import "./PerpdexStructs.sol";
import "./TakerLibrary.sol";

library MakerLibrary {
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
        uint128 liquidity;
        uint256 minBase;
        uint256 minQuote;
        uint256 deadline;
        address poolFactory;
    }

    struct RemoveLiquidityResponse {
        uint256 base;
        uint256 quote;
    }

    struct LiquidateParams {
        address baseToken;
        address quoteToken;
        uint128 liquidity;
        uint256 minBase;
        uint256 minQuote;
        uint256 oppositeAmountBound;
        uint256 deadline;
        address poolFactory;
    }

    function addLiquidity(PerpdexStructs.AccountInfo storage accountInfo, AddLiquidityParams memory params)
        public
        returns (AddLiquidityResponse)
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
        orderInfo.baseDebtShare = orderInfo.baseDebtShare.add(IBaseToken.balanceToShare(response.base));
        orderInfo.quoteDebt = orderInfo.quoteDebt.add(response.quote);
        orderInfo.liquidity = orderInfo.liquidity.add(response.liquidity.toUint128());

        require(AccountLibrary.hasEnoughInitialMargin(accountInfo));

        return
            AddLiquidityResponse({
                base: response.base,
                quote: response.quote,
                liquidity: response.liquidity.toUint128()
            });
    }

    function removeLiquidity(PerpdexStructs.AccountInfo storage accountInfo, RemoveLiquidityParams memory params)
        public
        returns (RemoveLiquidityResponse)
    {
        require(!AccountLibrary.isLiquidatable(accountInfo));

        UniswapV2Broker.RemoveLiquidityResponse memory response =
            UniswapV2Broker.removeLiquidity(
                UniswapV2Broker.RemoveLiquidityParams(
                    params.factory,
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
            response.base.toInt256().sub(IBaseToken(params.baseToken).shareToBalance(baseDebtShare).toInt256());
        int256 takerQuote = response.quote.toInt256().sub(quoteDebt.toInt256());
        TakerLibrary.addToTakerBalance(
            accountInfo.takerInfo[params.baseToken],
            params.baseToken,
            takerBase,
            takerQuote
        );

        return RemoveLiquidityResponse({ base: response.base, quote: response.quote });
    }

    function liquidate(PerpdexStructs.AccountInfo storage accountInfo, LiquidateParams memory params) public {
        require(AccountLibrary.isLiquidatable(accountInfo));

        UniswapV2Broker.RemoveLiquidityResponse memory response =
            UniswapV2Broker.removeLiquidity(
                UniswapV2Broker.RemoveLiquidityParams(
                    params.factory,
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
            response.base.toInt256().sub(IBaseToken(params.baseToken).shareToBalance(baseDebtShare).toInt256());
        int256 takerQuote = response.quote.toInt256().sub(quoteDebt.toInt256());
        TakerLibrary.addToTakerBalance(
            accountInfo.takerInfo[params.baseToken],
            params.baseToken,
            takerBase,
            takerQuote
        );
    }

    function _removeLiquidityFromOrder(PerpdexStructs.OrderInfo storage orderInfo, uint256 liquidity)
        internal
        returns (uint256 baseDebtShare, uint256 quoteDebt)
    {
        if (liquidity != 0) {
            if (orderInfo.baseDebtShare != 0) {
                baseDebtShare = FullMath.mulDiv(orderInfo.baseDebt, liquidity, orderInfo.liquidity);
                orderInfo.baseDebtShare = orderInfo.baseDebt.sub(baseDebtShare);
            }
            if (orderInfo.quoteDebt != 0) {
                quoteDebt = FullMath.mulDiv(orderInfo.quoteDebt, liquidity, orderInfo.liquidity);
                orderInfo.quoteDebt = orderInfo.quoteDebt.sub(quoteDebt);
            }
            orderInfo.liquidity = orderInfo.liquidity.sub(liquidity).toUint128();
        }

        return (baseDebtShare, quoteDebt);
    }
}
