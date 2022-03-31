// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { AddressUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import { SafeMathUpgradeable } from "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import { SignedSafeMathUpgradeable } from "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { PerpSafeCast } from "./lib/PerpSafeCast.sol";
import { PerpMath } from "./lib/PerpMath.sol";
import { Funding } from "./lib/Funding.sol";
import { SettlementTokenMath } from "./lib/SettlementTokenMath.sol";
import { OwnerPausable } from "./base/OwnerPausable.sol";
import { IERC20Metadata } from "./interface/IERC20Metadata.sol";
import { IVault } from "./interface/IVault.sol";
import { IExchangePerpdex } from "./interface/IExchangePerpdex.sol";
import { IOrderBookUniswapV2 } from "./interface/IOrderBookUniswapV2.sol";
import { IClearingHouseConfig } from "./interface/IClearingHouseConfig.sol";
import { IAccountBalance } from "./interface/IAccountBalance.sol";
import { BaseRelayRecipient } from "./gsn/BaseRelayRecipient.sol";
import { ClearingHousePerpdexStorageV1 } from "./storage/ClearingHousePerpdexStorage.sol";
import { BlockContext } from "./base/BlockContext.sol";
import { IClearingHouse } from "./interface/IClearingHouse.sol";
import { AccountMarket } from "./lib/AccountMarket.sol";
import { OpenOrder } from "./lib/OpenOrder.sol";

// never inherit any new stateful contract. never change the orders of parent stateful contracts
contract ClearingHousePerpdex is
    IClearingHousePerpdex,
    BlockContext,
    ReentrancyGuardUpgradeable,
    OwnerPausable,
    BaseRelayRecipient,
    ClearingHousePerpdexStorageV1
{
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;
    using SignedSafeMathUpgradeable for int256;
    using PerpSafeCast for uint256;
    using PerpSafeCast for uint128;
    using PerpSafeCast for int256;
    using PerpMath for uint256;
    using PerpMath for uint160;
    using PerpMath for uint128;
    using PerpMath for int256;
    using SettlementTokenMath for uint256;
    using SettlementTokenMath for int256;

    //
    // STRUCT
    //

    /// @param sqrtPriceLimitX96 tx will fill until it reaches this price but WON'T REVERT
    struct InternalOpenPositionParams {
        address trader;
        address baseToken;
        bool isBaseToQuote;
        bool isExactInput;
        bool isClose;
        uint256 amount;
        bool isLiquidation;
    }

    struct InternalClosePositionParams {
        address trader;
        address baseToken;
        bool isLiquidation;
    }

    struct InternalCheckSlippageParams {
        bool isBaseToQuote;
        bool isExactInput;
        uint256 base;
        uint256 quote;
        uint256 oppositeAmountBound;
    }

    //
    // MODIFIER
    //

    modifier onlyExchange() {
        // only exchange
        // For caller validation purposes it would be more efficient and more reliable to use
        // "msg.sender" instead of "_msgSender()" as contracts never call each other through GSN.
        require(msg.sender == _exchange, "CH_OE");
        _;
    }

    modifier checkDeadline(uint256 deadline) {
        // transaction expires
        require(_blockTimestamp() <= deadline, "CH_TE");
        _;
    }

    //
    // EXTERNAL NON-VIEW
    //

    /// @dev this function is public for testing
    // solhint-disable-next-line func-order
    function initialize(
        address clearingHouseConfigArg,
        address vaultArg,
        address quoteTokenArg,
        address uniV2FactoryArg,
        address exchangeArg,
        address accountBalanceArg,
        address insuranceFundArg
    ) public initializer {
        // CH_VANC: Vault address is not contract
        require(vaultArg.isContract(), "CH_VANC");
        // CH_QANC: QuoteToken address is not contract
        require(quoteTokenArg.isContract(), "CH_QANC");
        // CH_QDN18: QuoteToken decimals is not 18
        require(IERC20Metadata(quoteTokenArg).decimals() == 18, "CH_QDN18");
        // CH_UANC: UniV2Factory address is not contract
        require(uniV2FactoryArg.isContract(), "CH_UANC");
        // ClearingHouseConfig address is not contract
        require(clearingHouseConfigArg.isContract(), "CH_CCNC");
        // AccountBalance is not contract
        require(accountBalanceArg.isContract(), "CH_ABNC");
        // CH_ENC: Exchange is not contract
        require(exchangeArg.isContract(), "CH_ENC");
        // CH_IFANC: InsuranceFund address is not contract
        require(insuranceFundArg.isContract(), "CH_IFANC");

        address orderBookArg = IExchange(exchangeArg).getOrderBook();
        // orderBook is not contract
        require(orderBookArg.isContract(), "CH_OBNC");

        __ReentrancyGuard_init();
        __OwnerPausable_init();

        _clearingHouseConfig = clearingHouseConfigArg;
        _vault = vaultArg;
        _quoteToken = quoteTokenArg;
        _uniswapV2Factory = uniV2FactoryArg;
        _exchange = exchangeArg;
        _orderBook = orderBookArg;
        _accountBalance = accountBalanceArg;
        _insuranceFund = insuranceFundArg;

        _settlementTokenDecimals = IVault(_vault).decimals();
    }

    // solhint-disable-next-line func-order
    function setTrustedForwarder(address trustedForwarderArg) external onlyOwner {
        // CH_TFNC: TrustedForwarder is not contract
        require(trustedForwarderArg.isContract(), "CH_TFNC");
        _setTrustedForwarder(trustedForwarderArg);
        emit TrustedForwarderChanged(trustedForwarderArg);
    }

    /// @inheritdoc IClearingHouse
    function addLiquidity(AddLiquidityParams calldata params)
        external
        override
        whenNotPaused
        nonReentrant
        checkDeadline(params.deadline)
        returns (AddLiquidityResponse memory)
    {
        // input requirement checks:
        //   baseToken: in Exchange.settleFunding()
        //   base & quote: in LiquidityAmounts.getLiquidityForAmounts() -> FullMath.mulDiv()
        //   lowerTick & upperTick: in UniswapV3Pool._modifyPosition()
        //   minBase, minQuote & deadline: here

        // CH_DUTB: Disable useTakerBalance
        require(!params.useTakerBalance, "CH_DUTB");

        address trader = _msgSender();
        // register token if it's the first time
        IAccountBalance(_accountBalance).registerBaseToken(trader, params.baseToken);

        // must settle funding first
        Funding.Growth memory fundingGrowthGlobal = _settleFunding(trader, params.baseToken);

        // note that we no longer check available tokens here because CH will always auto-mint in UniswapV3MintCallback
        IOrderBookUniswapV2.AddLiquidityResponse memory response =
            IOrderBookUniswapV2(_orderBook).addLiquidity(
                IOrderBookUniswapV2.AddLiquidityParams({
                    trader: trader,
                    baseToken: params.baseToken,
                    base: params.base,
                    quote: params.quote,
                    fundingGrowthGlobal: fundingGrowthGlobal
                })
            );

        // CH_PSCF: price slippage check fails
        require(response.base >= params.minBase && response.quote >= params.minQuote, "CH_PSCF");

        // fees always have to be collected to owedRealizedPnl, as long as there is a change in liquidity
        IAccountBalance(_accountBalance).modifyOwedRealizedPnl(trader, response.fee.toInt256());

        // after token balances are updated, we can check if there is enough free collateral
        _requireEnoughFreeCollateral(trader);

        emit LiquidityChanged(
            trader,
            params.baseToken,
            _quoteToken,
            response.base.toInt256(),
            response.quote.toInt256(),
            response.liquidity.toInt128(),
            response.fee
        );

        return
            AddLiquidityResponse({
                base: response.base,
                quote: response.quote,
                fee: response.fee,
                liquidity: response.liquidity
            });
    }

    /// @inheritdoc IClearingHouse
    function removeLiquidity(RemoveLiquidityParams calldata params)
        external
        override
        whenNotPaused
        nonReentrant
        checkDeadline(params.deadline)
        returns (RemoveLiquidityResponse memory)
    {
        // input requirement checks:
        //   baseToken: in Exchange.settleFunding()
        //   lowerTick & upperTick: in UniswapV3Pool._modifyPosition()
        //   liquidity: in LiquidityMath.addDelta()
        //   minBase, minQuote & deadline: here

        address trader = _msgSender();

        // must settle funding first
        _settleFunding(trader, params.baseToken);

        IOrderBookUniswapV2.RemoveLiquidityResponse memory response =
            IOrderBookUniswapV2(_orderBook).removeLiquidity(
                IOrderBookUniswapV2.RemoveLiquidityParams({
                    maker: trader,
                    baseToken: params.baseToken,
                    liquidity: params.liquidity
                })
            );

        int256 realizedPnl = _settleBalanceAndRealizePnl(trader, params.baseToken, response);

        // CH_PSCF: price slippage check fails
        require(response.base >= params.minBase && response.quote >= params.minQuote, "CH_PSCF");

        emit LiquidityChanged(
            trader,
            params.baseToken,
            _quoteToken,
            response.base.neg256(),
            response.quote.neg256(),
            params.liquidity.neg128(),
            response.fee
        );

        int256 takerOpenNotional = IAccountBalance(_accountBalance).getTakerOpenNotional(trader, params.baseToken);

        // TODO: implement sqrtPrice
        uint256 sqrtPrice = IExchangePerpdex(_exchange).getSqrtMarkTwapX96(params.baseToken, 0);
        emit PositionChanged(
            trader,
            params.baseToken,
            response.takerBase, // exchangedPositionSize
            response.takerQuote, // exchangedPositionNotional
            0,
            takerOpenNotional, // openNotional
            realizedPnl, // realizedPnl
            sqrtPrice
        );

        return RemoveLiquidityResponse({ quote: response.quote, base: response.base, fee: response.fee });
    }

    /// @inheritdoc IClearingHouse
    function settleAllFunding(address trader) external override {
        address[] memory baseTokens = IAccountBalance(_accountBalance).getBaseTokens(trader);
        uint256 baseTokenLength = baseTokens.length;
        for (uint256 i = 0; i < baseTokenLength; i++) {
            _settleFunding(trader, baseTokens[i]);
        }
    }

    /// @inheritdoc IClearingHouse
    function openPosition(OpenPositionParams memory params)
        external
        override
        whenNotPaused
        nonReentrant
        checkDeadline(params.deadline)
        returns (uint256 base, uint256 quote)
    {
        // input requirement checks:
        //   baseToken: in Exchange.settleFunding()
        //   isBaseToQuote & isExactInput: X
        //   amount: in UniswapV3Pool.swap()
        //   oppositeAmountBound: in _checkSlippage()
        //   deadline: here
        //   sqrtPriceLimitX96: X (this is not for slippage protection)
        //   referralCode: X

        address trader = _msgSender();
        // register token if it's the first time
        IAccountBalance(_accountBalance).registerBaseToken(trader, params.baseToken);

        // must settle funding first
        _settleFunding(trader, params.baseToken);

        IExchangePerpdex.SwapResponse memory response =
            _openPosition(
                InternalOpenPositionParams({
                    trader: trader,
                    baseToken: params.baseToken,
                    isBaseToQuote: params.isBaseToQuote,
                    isExactInput: params.isExactInput,
                    amount: params.amount,
                    isClose: false,
                    isLiquidation: false
                })
            );

        _checkSlippage(
            InternalCheckSlippageParams({
                isBaseToQuote: params.isBaseToQuote,
                isExactInput: params.isExactInput,
                base: response.base,
                quote: response.quote,
                oppositeAmountBound: params.oppositeAmountBound
            })
        );

        if (params.referralCode != 0) {
            emit ReferredPositionChanged(params.referralCode);
        }
        return (response.base, response.quote);
    }

    /// @inheritdoc IClearingHouse
    function closePosition(ClosePositionParams calldata params)
        external
        override
        whenNotPaused
        nonReentrant
        checkDeadline(params.deadline)
        returns (uint256 base, uint256 quote)
    {
        // input requirement checks:
        //   baseToken: in Exchange.settleFunding()
        //   sqrtPriceLimitX96: X (this is not for slippage protection)
        //   oppositeAmountBound: in _checkSlippage()
        //   deadline: here
        //   referralCode: X

        address trader = _msgSender();

        // must settle funding first
        _settleFunding(trader, params.baseToken);

        IExchange.SwapResponse memory response =
            _closePosition(
                InternalClosePositionParams({ trader: trader, baseToken: params.baseToken, isLiquidation: false })
            );

        // if exchangedPositionSize < 0, closing it is short, B2Q; else, closing it is long, Q2B
        bool isBaseToQuote = response.exchangedPositionSize < 0 ? true : false;
        uint256 oppositeAmountBound = _getPartialOppositeAmount(params.oppositeAmountBound, response.isPartialClose);

        _checkSlippage(
            InternalCheckSlippageParams({
                isBaseToQuote: isBaseToQuote,
                isExactInput: isBaseToQuote,
                base: response.base,
                quote: response.quote,
                oppositeAmountBound: oppositeAmountBound
            })
        );

        if (params.referralCode != 0) {
            emit ReferredPositionChanged(params.referralCode);
        }
        return (response.base, response.quote);
    }

    /// @inheritdoc IClearingHouse
    function liquidate(
        address trader,
        address baseToken,
        uint256 oppositeAmountBound
    )
        external
        override
        whenNotPaused
        nonReentrant
        returns (
            uint256 base,
            uint256 quote,
            bool isPartialClose
        )
    {
        // getTakerPosSize == getTotalPosSize now, because it will revert in _liquidate() if there's any maker order
        int256 positionSize = IAccountBalance(_accountBalance).getTakerPositionSize(trader, baseToken);

        // if positionSize > 0, it's long base, and closing it is thus short base, B2Q;
        // else, closing it is long base, Q2B
        bool isBaseToQuote = positionSize > 0;

        (base, quote, isPartialClose) = _liquidate(trader, baseToken);

        oppositeAmountBound = _getPartialOppositeAmount(oppositeAmountBound, isPartialClose);
        _checkSlippage(
            InternalCheckSlippageParams({
                isBaseToQuote: isBaseToQuote,
                isExactInput: isBaseToQuote,
                base: base,
                quote: quote,
                oppositeAmountBound: oppositeAmountBound
            })
        );

        return (base, quote, isPartialClose);
    }

    /// @inheritdoc IClearingHouse
    function liquidate(address trader, address baseToken) external override whenNotPaused nonReentrant {
        _liquidate(trader, baseToken);
    }

    /// @inheritdoc IClearingHouse
    function cancelExcessOrders(
        address maker,
        address baseToken,
        bytes32[] calldata orderIds
    ) external override whenNotPaused nonReentrant {
        require(false, "not implemented");
        // input requirement checks:
        //   maker: in _cancelExcessOrders()
        //   baseToken: in Exchange.settleFunding()
        //   orderIds: in OrderBook.removeLiquidityByIds()
        //        _cancelExcessOrders(maker, baseToken, orderIds);
    }

    /// @inheritdoc IClearingHouse
    function cancelAllExcessOrders(address maker, address baseToken) external override whenNotPaused nonReentrant {
        require(false, "not implemented");

        // input requirement checks:
        //   maker: in _cancelExcessOrders()
        //   baseToken: in Exchange.settleFunding()
        //   orderIds: in OrderBook.removeLiquidityByIds()
        //        bytes32[] memory orderIds = IOrderBook(_orderBook).getOpenOrderIds(maker, baseToken);
        //        _cancelExcessOrders(maker, baseToken, orderIds);
    }

    //
    // EXTERNAL VIEW
    //

    /// @inheritdoc IClearingHouse
    function getQuoteToken() external view override returns (address) {
        return _quoteToken;
    }

    /// @inheritdoc IClearingHouse
    function getUniswapV2Factory() external view override returns (address) {
        return _uniswapV2Factory;
    }

    /// @inheritdoc IClearingHouse
    function getClearingHouseConfig() external view override returns (address) {
        return _clearingHouseConfig;
    }

    /// @inheritdoc IClearingHouse
    function getVault() external view override returns (address) {
        return _vault;
    }

    /// @inheritdoc IClearingHouse
    function getExchange() external view override returns (address) {
        return _exchange;
    }

    /// @inheritdoc IClearingHouse
    function getOrderBook() external view override returns (address) {
        return _orderBook;
    }

    /// @inheritdoc IClearingHouse
    function getAccountBalance() external view override returns (address) {
        return _accountBalance;
    }

    /// @inheritdoc IClearingHouse
    function getInsuranceFund() external view override returns (address) {
        return _insuranceFund;
    }

    /// @inheritdoc IClearingHouse
    function getAccountValue(address trader) public view override returns (int256) {
        int256 fundingPayment = IExchange(_exchange).getAllPendingFundingPayment(trader);
        (int256 owedRealizedPnl, int256 unrealizedPnl, uint256 pendingFee) =
            IAccountBalance(_accountBalance).getPnlAndPendingFee(trader);
        // solhint-disable-next-line var-name-mixedcase
        int256 balanceX10_18 =
            SettlementTokenMath.parseSettlementToken(IVault(_vault).getBalance(trader), _settlementTokenDecimals);

        // accountValue = collateralValue + owedRealizedPnl - fundingPayment + unrealizedPnl + pendingMakerFee
        return balanceX10_18.add(owedRealizedPnl.sub(fundingPayment)).add(unrealizedPnl).add(pendingFee.toInt256());
    }

    //
    // INTERNAL NON-VIEW
    //

    function _liquidate(address trader, address baseToken)
        internal
        returns (
            uint256 base,
            uint256 quote,
            bool isPartialClose
        )
    {
        // liquidation trigger:
        //   accountMarginRatio < accountMaintenanceMarginRatio
        //   => accountValue / sum(abs(positionValue_market)) <
        //        sum(mmRatio * abs(positionValue_market)) / sum(abs(positionValue_market))
        //   => accountValue < sum(mmRatio * abs(positionValue_market))
        //   => accountValue < sum(abs(positionValue_market)) * mmRatio = totalMinimumMarginRequirement
        //

        // input requirement checks:
        //   trader: here
        //   baseToken: in Exchange.settleFunding()

        // CH_CLWTISO: cannot liquidate when there is still order
        require(!IAccountBalance(_accountBalance).hasOrder(trader), "CH_CLWTISO");

        // CH_EAV: enough account value
        require(
            getAccountValue(trader) < IAccountBalance(_accountBalance).getMarginRequirementForLiquidation(trader),
            "CH_EAV"
        );

        // must settle funding first
        _settleFunding(trader, baseToken);
        IExchangePerpdex.SwapResponse memory response =
            _closePosition(InternalClosePositionParams({ trader: trader, baseToken: baseToken, isLiquidation: true }));

        // trader's pnl-- as liquidation penalty
        uint256 liquidationFee =
            response.exchangedPositionNotional.abs().mulRatio(
                IClearingHouseConfig(_clearingHouseConfig).getLiquidationPenaltyRatio()
            );

        IAccountBalance(_accountBalance).modifyOwedRealizedPnl(trader, liquidationFee.neg256());

        // increase liquidator's pnl liquidation reward
        address liquidator = _msgSender();
        IAccountBalance(_accountBalance).modifyOwedRealizedPnl(liquidator, liquidationFee.toInt256());

        emit PositionLiquidated(
            trader,
            baseToken,
            response.exchangedPositionNotional.abs(),
            response.base,
            liquidationFee,
            liquidator
        );

        return (response.base, response.quote, response.isPartialClose);
    }

    /// @dev Calculate how much profit/loss we should settled,
    /// only used when removing liquidity. The profit/loss is calculated by using
    /// the removed base/quote amount and existing taker's base/quote amount.
    function _settleBalanceAndRealizePnl(
        address maker,
        address baseToken,
        IOrderBook.RemoveLiquidityResponse memory response
    ) internal returns (int256) {
        int256 pnlToBeRealized;
        if (response.takerBase != 0) {
            pnlToBeRealized = IExchangePerpdex(_exchange).getPnlToBeRealized(
                IExchangePerpdex.RealizePnlParams({
                    trader: maker,
                    baseToken: baseToken,
                    base: response.takerBase,
                    quote: response.takerQuote
                })
            );
        }

        // pnlToBeRealized is realized here
        IAccountBalance(_accountBalance).settleBalanceAndDeregister(
            maker,
            baseToken,
            response.takerBase,
            response.takerQuote,
            pnlToBeRealized,
            response.fee.toInt256()
        );

        return pnlToBeRealized;
    }

    /// @dev explainer diagram for the relationship between exchangedPositionNotional, fee and openNotional:
    ///      https://www.figma.com/file/xuue5qGH4RalX7uAbbzgP3/swap-accounting-and-events
    function _openPosition(InternalOpenPositionParams memory params) internal returns (IExchange.SwapResponse memory) {
        IExchangePerpdex.SwapResponse memory response =
            IExchangePerpdex(_exchange).swap(
                IExchangePerpdex.SwapParams({
                    trader: params.trader,
                    baseToken: params.baseToken,
                    isBaseToQuote: params.isBaseToQuote,
                    isExactInput: params.isExactInput,
                    isClose: params.isClose,
                    amount: params.amount
                })
            );

        IAccountBalance(_accountBalance).modifyOwedRealizedPnl(_insuranceFund, response.insuranceFundFee.toInt256());

        // examples:
        // https://www.figma.com/file/xuue5qGH4RalX7uAbbzgP3/swap-accounting-and-events?node-id=0%3A1
        IAccountBalance(_accountBalance).modifyTakerBalance(
            params.trader,
            params.baseToken,
            response.exchangedPositionSize,
            response.exchangedPositionNotional.sub(response.fee.toInt256())
        );

        if (response.pnlToBeRealized != 0) {
            IAccountBalance(_accountBalance).settleQuoteToOwedRealizedPnl(
                params.trader,
                params.baseToken,
                response.pnlToBeRealized
            );

            // if realized pnl is not zero, that means trader is reducing or closing position
            // trader cannot reduce/close position if bad debt happen
            // unless it's a liquidation from backstop liquidity provider
            // CH_BD: trader has bad debt after reducing/closing position
            require(
                (params.isLiquidation &&
                    IClearingHouseConfig(_clearingHouseConfig).isBackstopLiquidityProvider(_msgSender())) ||
                    getAccountValue(params.trader) >= 0,
                "CH_BD"
            );
        }

        // if not closing a position, check margin ratio after swap
        if (!params.isClose) {
            _requireEnoughFreeCollateral(params.trader);
        }

        int256 openNotional = IAccountBalance(_accountBalance).getTakerOpenNotional(params.trader, params.baseToken);
        emit PositionChanged(
            params.trader,
            params.baseToken,
            response.exchangedPositionSize,
            response.exchangedPositionNotional,
            response.fee,
            openNotional,
            response.pnlToBeRealized,
            response.sqrtPriceAfterX96
        );

        IAccountBalance(_accountBalance).deregisterBaseToken(params.trader, params.baseToken);

        return response;
    }

    /// @dev The actual close position logic.
    function _closePosition(InternalClosePositionParams memory params)
        internal
        returns (IExchangePerpdex.SwapResponse memory)
    {
        int256 positionSize = IAccountBalance(_accountBalance).getTakerPositionSize(params.trader, params.baseToken);

        // CH_PSZ: position size is zero
        require(positionSize != 0, "CH_PSZ");

        // old position is long. when closing, it's baseToQuote && exactInput (sell exact base)
        // old position is short. when closing, it's quoteToBase && exactOutput (buy exact base back)
        bool isBaseToQuote = positionSize > 0;
        return
            _openPosition(
                InternalOpenPositionParams({
                    trader: params.trader,
                    baseToken: params.baseToken,
                    isBaseToQuote: isBaseToQuote,
                    isExactInput: isBaseToQuote,
                    isClose: true,
                    amount: positionSize.abs(),
                    isLiquidation: params.isLiquidation
                })
            );
    }

    /// @dev Settle trader's funding payment to his/her realized pnl.
    function _settleFunding(address trader, address baseToken)
        internal
        returns (Funding.Growth memory fundingGrowthGlobal)
    {
        int256 fundingPayment;
        (fundingPayment, fundingGrowthGlobal) = IExchangePerpdex(_exchange).settleFunding(trader, baseToken);

        if (fundingPayment != 0) {
            IAccountBalance(_accountBalance).modifyOwedRealizedPnl(trader, fundingPayment.neg256());
            emit FundingPaymentSettled(trader, baseToken, fundingPayment);
        }

        IAccountBalance(_accountBalance).updateTwPremiumGrowthGlobal(
            trader,
            baseToken,
            fundingGrowthGlobal.twPremiumX96
        );
        return fundingGrowthGlobal;
    }

    //
    // INTERNAL VIEW
    //

    /// @inheritdoc BaseRelayRecipient
    function _msgSender() internal view override(BaseRelayRecipient, OwnerPausable) returns (address payable) {
        return super._msgSender();
    }

    /// @inheritdoc BaseRelayRecipient
    function _msgData() internal view override(BaseRelayRecipient, OwnerPausable) returns (bytes memory) {
        return super._msgData();
    }

    function _getFreeCollateralByRatio(address trader, uint24 ratio) internal view returns (int256) {
        return IVault(_vault).getFreeCollateralByRatio(trader, ratio);
    }

    function _requireEnoughFreeCollateral(address trader) internal view {
        // CH_NEFCI: not enough free collateral by imRatio
        require(
            _getFreeCollateralByRatio(trader, IClearingHouseConfig(_clearingHouseConfig).getImRatio()) >= 0,
            "CH_NEFCI"
        );
    }

    function _getPartialOppositeAmount(uint256 oppositeAmountBound, bool isPartialClose)
        internal
        view
        returns (uint256)
    {
        return
            isPartialClose
                ? oppositeAmountBound.mulRatio(IClearingHouseConfig(_clearingHouseConfig).getPartialCloseRatio())
                : oppositeAmountBound;
    }

    function _checkSlippage(InternalCheckSlippageParams memory params) internal pure {
        // skip when params.oppositeAmountBound is zero
        if (params.oppositeAmountBound == 0) {
            return;
        }

        // B2Q + exact input, want more output quote as possible, so we set a lower bound of output quote
        // B2Q + exact output, want less input base as possible, so we set a upper bound of input base
        // Q2B + exact input, want more output base as possible, so we set a lower bound of output base
        // Q2B + exact output, want less input quote as possible, so we set a upper bound of input quote
        if (params.isBaseToQuote) {
            if (params.isExactInput) {
                // too little received when short
                require(params.quote >= params.oppositeAmountBound, "CH_TLRS");
            } else {
                // too much requested when short
                require(params.base <= params.oppositeAmountBound, "CH_TMRS");
            }
        } else {
            if (params.isExactInput) {
                // too little received when long
                require(params.base >= params.oppositeAmountBound, "CH_TLRL");
            } else {
                // too much requested when long
                require(params.quote <= params.oppositeAmountBound, "CH_TMRL");
            }
        }
    }
}
