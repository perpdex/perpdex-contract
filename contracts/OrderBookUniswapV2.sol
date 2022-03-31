// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { SafeMathUpgradeable } from "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import { SignedSafeMathUpgradeable } from "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import { FullMath } from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import { TickMath } from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import { SwapMath } from "@uniswap/v3-core/contracts/libraries/SwapMath.sol";
import { LiquidityMath } from "@uniswap/v3-core/contracts/libraries/LiquidityMath.sol";
import { FixedPoint128 } from "@uniswap/v3-core/contracts/libraries/FixedPoint128.sol";
import { LiquidityAmounts } from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import { UniswapV2Broker } from "./lib/UniswapV2Broker.sol";
import { PerpSafeCast } from "./lib/PerpSafeCast.sol";
import { PerpFixedPoint96 } from "./lib/PerpFixedPoint96.sol";
import { Funding } from "./lib/Funding.sol";
import { PerpMath } from "./lib/PerpMath.sol";
import { Tick } from "./lib/Tick.sol";
import { ClearingHouseCallee } from "./base/ClearingHouseCallee.sol";
import { IMarketRegistry } from "./interface/IMarketRegistry.sol";
import { OrderBookUniswapV2StorageV1 } from "./storage/OrderBookUniswapV2StorageV1.sol";
import { IOrderBookUniswapV2 } from "./interface/IOrderBookUniswapV2.sol";
import { OpenOrder } from "./lib/OpenOrder.sol";

// never inherit any new stateful contract. never change the orders of parent stateful contracts
contract OrderBookUniswapV2 is IOrderBookUniswapV2, ClearingHouseCallee, OrderBookUniswapV2StorageV1 {
    using SafeMathUpgradeable for uint256;
    using SafeMathUpgradeable for uint128;
    using SignedSafeMathUpgradeable for int256;
    using PerpMath for uint256;
    using PerpMath for uint160;
    using PerpMath for int256;
    using PerpMath for int128;
    using PerpSafeCast for uint256;
    using PerpSafeCast for uint128;
    using PerpSafeCast for int256;
    using Tick for mapping(int24 => Tick.GrowthInfo);

    //
    // STRUCT
    //

    struct InternalAddLiquidityToOrderParams {
        address maker;
        IUniswapV2Router02 router;
        address baseToken;
        address quoteToken;
        uint128 liquidity;
        uint256 base;
        uint256 quote;
        Funding.Growth globalFundingGrowth;
    }

    struct InternalRemoveLiquidityParams {
        address maker;
        IUniswapV2Router02 router;
        address baseToken;
        address quoteToken;
        bytes32 orderId;
        uint128 liquidity;
    }

    struct InternalSwapStep {
        uint160 initialSqrtPriceX96;
        int24 nextTick;
        bool isNextTickInitialized;
        uint160 nextSqrtPriceX96;
        uint256 amountIn;
        uint256 amountOut;
        uint256 fee;
    }

    //
    // EXTERNAL NON-VIEW
    //

    function initialize(address marketRegistryArg) external initializer {
        __ClearingHouseCallee_init();
    }

    function setExchange(address exchangeArg) external onlyOwner {
        _exchange = exchangeArg;
        emit ExchangeChanged(exchangeArg);
    }

    /// @inheritdoc IOrderBook
    function addLiquidity(AddLiquidityParams calldata params) external override returns (AddLiquidityResponse memory) {
        _requireOnlyClearingHouse();
        address router = IMarketRegistry(_marketRegistry).getUniswapV2Router02();
        address quoteToken = IMarketRegistry(_marketRegistry).getQuoteToken();
        //        uint256 feeGrowthGlobalX128 = _feeGrowthGlobalX128Map[params.baseToken];
        //        mapping(int24 => Tick.GrowthInfo) storage tickMap = _growthOutsideTickMap[params.baseToken];
        UniswapV2Broker.AddLiquidityResponse memory response;

        {
            // add liquidity to pool
            response = UniswapV2Broker.addLiquidity(
                UniswapV2Broker.AddLiquidityParams(router, params.baseToken, quoteToken, params.base, params.quote)
            );

            a = feeGrowthGlobalX128;
            a = params.fundingGrowthGlobal.twPremiumX96;
            a = params.fundingGrowthGlobal.twPremiumDivBySqrtPriceX96;
        }

        // state changes; if adding liquidity to an existing order, get fees accrued
        uint256 fee =
            _addLiquidityToOrder(
                InternalAddLiquidityToOrderParams({
                    maker: params.trader,
                    router: router,
                    baseToken: params.baseToken,
                    quoteToken: quoteToken,
                    liquidity: response.liquidity,
                    base: response.base,
                    quote: response.quote,
                    globalFundingGrowth: params.fundingGrowthGlobal
                })
            );

        return
            AddLiquidityResponse({
                base: response.base,
                quote: response.quote,
                fee: fee,
                liquidity: response.liquidity
            });
    }

    /// @inheritdoc IOrderBook
    function removeLiquidity(RemoveLiquidityParams calldata params)
        external
        override
        returns (RemoveLiquidityResponse memory)
    {
        _requireOnlyClearingHouse();
        IUniswapV2Router02 router = IMarketRegistry(_marketRegistry).getUniswapV2Router02();
        bytes32 orderId = OpenOrder.calcOrderKey(params.maker, params.baseToken, 0, 0);
        return
            _removeLiquidity(
                InternalRemoveLiquidityParams({
                    maker: params.maker,
                    baseToken: params.baseToken,
                    pool: pool,
                    orderId: orderId,
                    liquidity: params.liquidity
                })
            );
    }

    /// @inheritdoc IOrderBook
    function updateFundingGrowthAndLiquidityCoefficientInFundingPayment(
        address trader,
        address baseToken,
        Funding.Growth memory fundingGrowthGlobal
    ) external override returns (int256 liquidityCoefficientInFundingPayment) {
        _requireOnlyExchange();

        //        bytes32[] memory orderIds = _openOrderIdsMap[trader][baseToken];
        //        mapping(int24 => Tick.GrowthInfo) storage tickMap = _growthOutsideTickMap[baseToken];
        //        address pool = IMarketRegistry(_marketRegistry).getPool(baseToken);
        address router = IMarketRegistry(_marketRegistry).getUniswapV2Router02();

        // funding of liquidity coefficient
        //        uint256 orderIdLength = orderIds.length;
        //        (, int24 tick, , , , , ) = UniswapV3Broker.getSlot0(pool);
        //        for (uint256 i = 0; i < orderIdLength; i++) {
        {
            OpenOrder.Info storage order = _openOrder;
            //            Tick.FundingGrowthRangeInfo memory fundingGrowthRangeInfo =
            //                tickMap.getAllFundingGrowth(
            //                    order.lowerTick,
            //                    order.upperTick,
            //                    tick,
            //                    fundingGrowthGlobal.twPremiumX96,
            //                    fundingGrowthGlobal.twPremiumDivBySqrtPriceX96
            //                );

            // TODO: process funding

            // the calculation here is based on cached values
            liquidityCoefficientInFundingPayment = liquidityCoefficientInFundingPayment.add(
                Funding.calcLiquidityCoefficientInFundingPaymentByOrder(order, fundingGrowthRangeInfo)
            );

            // thus, state updates have to come after

            a = feeGrowthGlobalX128;
            a = params.fundingGrowthGlobal.twPremiumX96;
            a = params.fundingGrowthGlobal.twPremiumDivBySqrtPriceX96;

            //            order.lastTwPremiumGrowth =
            //            order.lastTwPremiumGrowthInsideX96 = fundingGrowthRangeInfo.twPremiumGrowthInsideX96;
            //            order.lastTwPremiumGrowthBelowX96 = fundingGrowthRangeInfo.twPremiumGrowthBelowX96;
            //            order.lastTwPremiumDivBySqrtPriceGrowthInsideX96 = fundingGrowthRangeInfo
            //                .twPremiumDivBySqrtPriceGrowthInsideX96;
        }

        return liquidityCoefficientInFundingPayment;
    }

    /// @inheritdoc IOrderBook
    function updateOrderDebt(
        bytes32 orderId,
        int256 base,
        int256 quote
    ) external override {
        _requireOnlyClearingHouse();
        require(orderId == 0); // TODO: remove orderId
        OpenOrder.Info storage openOrder = _openOrder; // _openOrderMap[orderId];
        openOrder.baseDebt = openOrder.baseDebt.toInt256().add(base).toUint256();
        openOrder.quoteDebt = openOrder.quoteDebt.toInt256().add(quote).toUint256();
    }

    //
    // EXTERNAL VIEW
    //

    /// @inheritdoc IOrderBook
    function getExchange() external view override returns (address) {
        return _exchange;
    }

    /// @inheritdoc IOrderBook
    function getOpenOrderIds(address trader, address baseToken) external view override returns (bytes32[] memory) {
        return _openOrderIdsMap[trader][baseToken];
    }

    /// @inheritdoc IOrderBook
    function getOpenOrderById(bytes32 orderId) external view override returns (OpenOrder.Info memory) {
        return _openOrderMap[orderId];
    }

    /// @inheritdoc IOrderBook
    function getOpenOrder(address trader, address baseToken)
        external
        view
        override
        returns (
            //        int24 lowerTick,
            //        int24 upperTick
            OpenOrder.Info memory
        )
    {
        return _openOrder;
        //        return _openOrderMap[OpenOrder.calcOrderKey(trader, baseToken, lowerTick, upperTick)];
    }

    /// @inheritdoc IOrderBook
    function hasOrder(address trader, address[] calldata tokens) external view override returns (bool) {
        return _openOrder.liquidity > 0;
        //        for (uint256 i = 0; i < tokens.length; i++) {
        //            if (_openOrderIdsMap[trader][tokens[i]].length > 0) {
        //                return true;
        //            }
        //        }
        //        return false;
    }

    /// @inheritdoc IOrderBook
    function getTotalQuoteBalanceAndPendingFee(address trader, address[] calldata baseTokens)
        external
        view
        override
        returns (int256 totalQuoteAmountInPools, uint256 totalPendingFee)
    {
        for (uint256 i = 0; i < baseTokens.length; i++) {
            address baseToken = baseTokens[i];
            (int256 makerQuoteBalance, uint256 pendingFee) =
                _getMakerQuoteBalanceAndPendingFee(trader, baseToken, false);
            totalQuoteAmountInPools = totalQuoteAmountInPools.add(makerQuoteBalance);
            totalPendingFee = totalPendingFee.add(pendingFee);
        }
        return (totalQuoteAmountInPools, totalPendingFee);
    }

    /// @inheritdoc IOrderBook
    function getTotalTokenAmountInPoolAndPendingFee(
        address trader,
        address baseToken,
        bool fetchBase // true: fetch base amount, false: fetch quote amount
    ) external view override returns (uint256 tokenAmount, uint256 pendingFee) {
        (tokenAmount, pendingFee) = _getTotalTokenAmountInPool(trader, baseToken, fetchBase);
    }

    /// @inheritdoc IOrderBook
    function getLiquidityCoefficientInFundingPayment(
        address trader,
        address baseToken,
        Funding.Growth memory fundingGrowthGlobal
    ) external view override returns (int256 liquidityCoefficientInFundingPayment) {
        bytes32[] memory orderIds = _openOrderIdsMap[trader][baseToken];
        mapping(int24 => Tick.GrowthInfo) storage tickMap = _growthOutsideTickMap[baseToken];
        address pool = IMarketRegistry(_marketRegistry).getPool(baseToken);

        // funding of liquidity coefficient
        //        (, int24 tick, , , , , ) = UniswapV3Broker.getSlot0(pool);
        //        for (uint256 i = 0; i < orderIds.length; i++) {
        {
            OpenOrder.Info memory order = _openOrder; // _openOrderMap[orderIds[i]];
            //            Tick.FundingGrowthRangeInfo memory fundingGrowthRangeInfo =
            //                tickMap.getAllFundingGrowth(
            //                    order.lowerTick,
            //                    order.upperTick,
            //                    tick,
            //                    fundingGrowthGlobal.twPremiumX96,
            //                    fundingGrowthGlobal.twPremiumDivBySqrtPriceX96
            //                );

            // the calculation here is based on cached values
            liquidityCoefficientInFundingPayment = liquidityCoefficientInFundingPayment.add(
                Funding.calcLiquidityCoefficientInFundingPaymentByOrder(order, fundingGrowthRangeInfo)
            );
        }

        return liquidityCoefficientInFundingPayment;
    }

    /// @inheritdoc IOrderBook
    function getPendingFee(address trader, address baseToken)
        external
        view
        override
        returns (
            //        int24 lowerTick,
            //        int24 upperTick
            uint256
        )
    {
        return 0;
        //        (uint256 pendingFee, ) =
        //            _getPendingFeeAndFeeGrowthInsideX128ByOrder(
        //                baseToken,
        //                _openOrder
        ////                _openOrderMap[OpenOrder.calcOrderKey(trader, baseToken, lowerTick, upperTick)]
        //            );
        //        return pendingFee;
    }

    //
    // PUBLIC VIEW
    //

    /// @inheritdoc IOrderBook
    function getTotalOrderDebt(
        address trader,
        address baseToken,
        bool fetchBase
    ) public view override returns (uint256) {
        uint256 totalOrderDebt;
        //        bytes32[] memory orderIds = _openOrderIdsMap[trader][baseToken];
        //        uint256 orderIdLength = orderIds.length;
        //        for (uint256 i = 0; i < orderIdLength; i++) {
        {
            OpenOrder.Info memory orderInfo = _openOrder; // _openOrderMap[orderIds[i]];
            uint256 orderDebt = fetchBase ? orderInfo.baseDebt : orderInfo.quoteDebt;
            totalOrderDebt = totalOrderDebt.add(orderDebt);
        }
        return totalOrderDebt;
    }

    //
    // INTERNAL NON-VIEW
    //

    function _removeLiquidity(InternalRemoveLiquidityParams memory params)
        internal
        returns (RemoveLiquidityResponse memory)
    {
        UniswapV2Broker.RemoveLiquidityResponse memory response =
            UniswapV2Broker.removeLiquidity(
                UniswapV2Broker.RemoveLiquidityParams(
                    params.router,
                    params.baseToken,
                    params.quoteToken,
                    _exchange,
                    params.liquidity
                )
            );

        // update token info based on existing open order
        (uint256 fee, uint256 baseDebt, uint256 quoteDebt) = _removeLiquidityFromOrder(params);

        int256 takerBase = response.base.toInt256().sub(baseDebt.toInt256());
        int256 takerQuote = response.quote.toInt256().sub(quoteDebt.toInt256());

        // if flipped from initialized to uninitialized, clear the tick info
        //        if (!UniswapV3Broker.getIsTickInitialized(params.pool, params.lowerTick)) {
        //            _growthOutsideTickMap[params.baseToken].clear(params.lowerTick);
        //        }
        //        if (!UniswapV3Broker.getIsTickInitialized(params.pool, params.upperTick)) {
        //            _growthOutsideTickMap[params.baseToken].clear(params.upperTick);
        //        }

        return
            RemoveLiquidityResponse({
                base: response.base,
                quote: response.quote,
                fee: fee,
                takerBase: takerBase,
                takerQuote: takerQuote
            });
    }

    function _removeLiquidityFromOrder(InternalRemoveLiquidityParams memory params)
        internal
        returns (
            uint256 fee,
            uint256 baseDebt,
            uint256 quoteDebt
        )
    {
        // update token info based on existing open order
        OpenOrder.Info storage openOrder = _openOrder; // openOrderMap[params.orderId];

        // as in _addLiquidityToOrder(), fee should be calculated before the states are updated
        //        uint256 feeGrowthInsideX128;
        //        (fee, feeGrowthInsideX128) = _getPendingFeeAndFeeGrowthInsideX128ByOrder(params.baseToken, openOrder);

        if (params.liquidity != 0) {
            if (openOrder.baseDebt != 0) {
                baseDebt = FullMath.mulDiv(openOrder.baseDebt, params.liquidity, openOrder.liquidity);
                openOrder.baseDebt = openOrder.baseDebt.sub(baseDebt);
            }
            if (openOrder.quoteDebt != 0) {
                quoteDebt = FullMath.mulDiv(openOrder.quoteDebt, params.liquidity, openOrder.liquidity);
                openOrder.quoteDebt = openOrder.quoteDebt.sub(quoteDebt);
            }
            openOrder.liquidity = openOrder.liquidity.sub(params.liquidity).toUint128();
        }

        // after the fee is calculated, lastFeeGrowthInsideX128 can be updated if liquidity != 0 after removing
        if (openOrder.liquidity == 0) {
            //            _removeOrder(params.maker, params.baseToken, params.orderId);
        } else {
            openOrder.lastFeeGrowthInsideX128 = feeGrowthInsideX128;
        }

        return (fee, baseDebt, quoteDebt);
    }

    /// @dev this function is extracted from and only used by addLiquidity() to avoid stack too deep error
    function _addLiquidityToOrder(InternalAddLiquidityToOrderParams memory params) internal returns (uint256) {
        //        bytes32 orderId = OpenOrder.calcOrderKey(params.maker, params.baseToken, 0, 0);
        // get the struct by key, no matter it's a new or existing order
        OpenOrder.Info storage openOrder = _openOrder; // _openOrderMap[orderId];

        // initialization for a new order
        if (openOrder.liquidity == 0) {
            //            bytes32[] storage orderIds = _openOrderIdsMap[params.maker][params.baseToken];
            // OB_ONE: orders number exceeds
            //            require(orderIds.length < IMarketRegistry(_marketRegistry).getMaxOrdersPerMarket(), "OB_ONE");

            // state changes
            //            orderIds.push(orderId);

            openOrder.lastTwPremiumGrowth = params.globalFundingGrowth.twPremiumX96;
            openOrder.lastTwPremiumDivBySqrtPriceGrowthInsideX96 = params
                .globalFundingGrowth
                .twPremiumDivBySqrtPriceX96;
        }

        // fee should be calculated before the states are updated, as for
        // - a new order, there is no fee accrued yet
        // - an existing order, fees accrued have to be settled before more liquidity is added
        //        (uint256 fee, uint256 feeGrowthInsideX128) =
        //            _getPendingFeeAndFeeGrowthInsideX128ByOrder(params.baseToken, openOrder);

        // TODO: process funding

        // after the fee is calculated, liquidity & lastFeeGrowthInsideX128 can be updated
        openOrder.liquidity = openOrder.liquidity.add(params.liquidity).toUint128();
        //        openOrder.lastFeeGrowthInsideX128 = feeGrowthInsideX128;
        openOrder.baseDebt = openOrder.baseDebt.add(params.base);
        openOrder.quoteDebt = openOrder.quoteDebt.add(params.quote);

        uint256 fee = 0;
        return fee;
    }

    //
    // INTERNAL VIEW
    //

    /// @return makerBalance maker quote balance
    /// @return pendingFee pending fee
    function _getMakerQuoteBalanceAndPendingFee(
        address trader,
        address baseToken,
        bool fetchBase
    ) internal view returns (int256 makerBalance, uint256 pendingFee) {
        (uint256 totalBalanceFromOrders, uint256 pendingFee) = _getTotalTokenAmountInPool(trader, baseToken, fetchBase);
        uint256 totalOrderDebt = getTotalOrderDebt(trader, baseToken, fetchBase);

        // makerBalance = totalTokenAmountInPool - totalOrderDebt
        return (totalBalanceFromOrders.toInt256().sub(totalOrderDebt.toInt256()), pendingFee);
    }

    /// @dev Get total amount of the specified tokens in the specified pool.
    ///      Note:
    ///        1. when querying quote amount, it includes Exchange fees, i.e.:
    ///           quote amount = quote liquidity + fees
    ///           base amount = base liquidity
    ///        2. quote/base liquidity does NOT include Uniswap pool fees since
    ///           they do not have any impact to our margin system
    ///        3. the returned fee amount is only meaningful when querying quote amount
    function _getTotalTokenAmountInPool(
        address trader,
        address baseToken, // this argument is only for specifying which pool to get base or quote amounts
        bool fetchBase // true: fetch base amount, false: fetch quote amount
    ) internal view returns (uint256 tokenAmount, uint256 pendingFee) {
        //        bytes32[] memory orderIds = _openOrderIdsMap[trader][baseToken];

        IUniswapV2Router02 router = IMarketRegistry(_marketRegistry).getUniswapV2Router02();
        address quoteToken = IMarketRegistry(_marketRegistry).getQuoteToken();

        //        uint256 orderIdLength = orderIds.length;

        //        for (uint256 i = 0; i < orderIdLength; i++) {
        {
            OpenOrder.Info memory order = _openOrder; // _openOrderMap[orderIds[i]];

            uint256 amount;
            {
                (uint256 baseAmount, uint256 quoteAmount) =
                    UniswapV2Broker.getLiquidityValue(router.factory(), baseToken, quoteToken, order.liquidity);

                if (fetchBase) {
                    amount = baseAmount;
                } else {
                    amount = quoteAmount;
                }
            }
            tokenAmount = tokenAmount.add(amount);
        }
        return (tokenAmount, pendingFee);
    }

    function _requireOnlyExchange() internal view {
        // OB_OEX: Only exchange
        require(_msgSender() == _exchange, "OB_OEX");
    }
}
