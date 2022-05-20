// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { AddressUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20Metadata } from "./interface/IERC20Metadata.sol";
import { BlockContext } from "./base/BlockContext.sol";
import { IClearingHousePerpdex } from "./interface/IClearingHousePerpdex.sol";
import { PerpdexStructs } from "./lib/PerpdexStructs.sol";
import { MakerLibrary } from "./lib/MakerLibrary.sol";
import { TakerLibrary } from "./lib/TakerLibrary.sol";
import { VaultLibrary } from "./lib/VaultLibrary.sol";

// never inherit any new stateful contract. never change the orders of parent stateful contracts
contract ClearingHousePerpdex is IClearingHousePerpdex, ReentrancyGuard {
    using AddressUpgradeable for address;

    // states
    // trader
    mapping(address => PerpdexStructs.AccountInfo) public accountInfos;
    // baseToken
    mapping(address => PerpdexStructs.PriceLimitInfo) public priceLimitInfos;
    PerpdexStructs.InsuranceFundInfo public insuranceFundInfo;

    // config
    address immutable quoteToken;
    address immutable uniV2Factory;
    PerpdexStructs public priceLimitConfig;
    uint8 public maxMarketsPerAccount;
    uint24 public imRatio;
    uint24 public mmRatio;
    uint24 public liquidationRewardRatio;
    uint32 public twapInterval;
    uint24 public maxFundingRateRatio;

    //
    // MODIFIER
    //

    //
    // EXTERNAL NON-VIEW
    //

    constructor(address quoteTokenArg, address uniV2FactoryArg) public {
        // CH_QANC: QuoteToken address is not contract
        require(quoteTokenArg.isContract(), "CH_QANC");
        // CH_QDN18: QuoteToken decimals is not 18
        require(IERC20Metadata(quoteTokenArg).decimals() == 18, "CH_QDN18");
        // CH_UANC: UniV2Factory address is not contract
        require(uniV2FactoryArg.isContract(), "CH_UANC");

        quoteToken = quoteTokenArg;
        uniV2Factory = uniV2FactoryArg;
    }

    function deposit(address token, uint256 amount) external override nonReentrant {
        VaultLibrary.deposit(VaultLibrary.DepositParams({ token: token, amount: amount }));
    }

    function withdraw(address token, uint256 amount) external override nonReentrant {
        VaultLibrary.withdraw(VaultLibrary.WithdrawParams({ token: token, amount: amount }));
    }

    /// @inheritdoc IClearingHousePerpdex
    function addLiquidity(AddLiquidityParams calldata params)
        external
        override
        nonReentrant
        returns (AddLiquidityResponse memory)
    {
        address maker = _msgSender();

        MakerLibrary.AddLiquidityResponse memory response =
            MakerLibrary.addLiquidity(
                accountInfos[maker],
                priceLimitInfos[params.baseToken],
                TakerLibrary.OpenPositionParams({
                    baseToken: params.baseToken,
                    isBaseToQuote: params.isBaseToQuote,
                    isExactInput: params.isExactInput,
                    amount: params.amount,
                    oppositeAmountBound: params.oppositeAmountBound,
                    deadline: params.deadline,
                    poolFactory: uniV2Factory,
                    priceLimitConfig: priceLimitConfig
                })
            );

        emit LiquidityChanged(
            maker,
            params.baseToken,
            quoteToken,
            response.base.toInt256(),
            response.quote.toInt256(),
            response.liquidity.toInt128(),
            response.fee
        );

        return response;
    }

    /// @inheritdoc IClearingHousePerpdex
    function removeLiquidity(RemoveLiquidityParams calldata params)
        external
        override
        nonReentrant
        returns (RemoveLiquidityResponse memory)
    {
        address maker = _msgSender();

        RemoveLiquidityResponse memory response = MakerLibrary.removeLiquidity(accountInfos[maker], params);

        emit LiquidityChanged(
            maker,
            params.baseToken,
            quoteToken,
            response.base.toInt256(),
            response.quote.toInt256(),
            response.liquidity.toInt128(),
            response.fee
        );

        //        emit PositionChanged(
        //            maker,
        //            params.baseToken,
        //            response.takerBase, // exchangedPositionSize
        //            response.takerQuote, // exchangedPositionNotional
        //            0,
        //            takerOpenNotional, // openNotional
        //            realizedPnl, // realizedPnl
        //            sqrtPrice
        //        );

        return response;
    }

    /// @inheritdoc IClearingHousePerpdex
    function liquidateMaker(address maker, address baseToken) external override nonReentrant {
        //        MakerLibrary.liquidate(
        //            accountInfos[maker],
        //            params
        //        );
    }

    /// @inheritdoc IClearingHousePerpdex
    function openPosition(OpenPositionParams memory params)
        external
        override
        nonReentrant
        returns (uint256 base, uint256 quote)
    {
        address trader = _msgSender();

        TakerLibrary.OpenPositionResponse memory response =
            TakerLibrary.openPosition(
                accountInfos[trader],
                priceLimitInfos[params.baseToken],
                TakerLibrary.OpenPositionParams({
                    baseToken: params.baseToken,
                    isBaseToQuote: params.isBaseToQuote,
                    isExactInput: params.isExactInput,
                    amount: params.amount,
                    oppositeAmountBound: params.oppositeAmountBound,
                    deadline: params.deadline,
                    poolFactory: uniV2Factory,
                    priceLimitConfig: priceLimitConfig
                })
            );

        //        emit PositionChanged(
        //            trader,
        //            params.baseToken,
        //            response.exchangedPositionSize,
        //            response.exchangedPositionNotional,
        //            response.fee,
        //            openNotional,
        //            response.pnlToBeRealized,
        //            response.sqrtPriceAfterX96
        //        );

        return (response.base, response.quote);
    }

    /// @inheritdoc IClearingHousePerpdex
    function closePosition(ClosePositionParams calldata params)
        external
        override
        nonReentrant
        returns (uint256 base, uint256 quote)
    {
        address trader = _msgSender();

        TakerLibrary.ClosePositionResponse memory response =
            TakerLibrary.closePosition(
                accountInfos[trader],
                priceLimitInfos[params.baseToken],
                TakerLibrary.ClosePositionParams({
                    baseToken: params.baseToken,
                    oppositeAmountBound: params.oppositeAmountBound,
                    deadline: params.deadline,
                    poolFactory: uniV2Factory,
                    priceLimitConfig: priceLimitConfig
                })
            );

        emit PositionChanged(
            trader,
            params.baseToken,
            response.exchangedPositionSize,
            response.exchangedPositionNotional,
            response.fee,
            openNotional,
            response.pnlToBeRealized,
            response.sqrtPriceAfterX96
        );

        return (response.base, response.quote);
    }

    /// @inheritdoc IClearingHousePerpdex
    function liquidateTaker(
        address trader,
        address baseToken,
        uint256 oppositeAmountBound
    ) external override nonReentrant returns (uint256 base, uint256 quote) {
        address liquidator = _msgSender();

        TakerLibrary.LiquidateResponse memory response =
            TakerLibrary.liquidate(
                accountInfos[trader],
                accountInfos[liquidator],
                priceLimitInfos[params.baseToken],
                insuranceFundInfo,
                TakerLibrary.LiquidateParams({
                    baseToken: params.baseToken,
                    amount: params.amount,
                    oppositeAmountBound: params.oppositeAmountBound,
                    deadline: params.deadline,
                    poolFactory: uniV2Factory,
                    priceLimitConfig: priceLimitConfig,
                    mmRatio: mmRatio,
                    liquidationRewardRatio: liquidationRewardRatio
                })
            );

        emit PositionChanged(
            trader,
            params.baseToken,
            response.exchangedPositionSize,
            response.exchangedPositionNotional,
            response.fee,
            openNotional,
            response.pnlToBeRealized,
            response.sqrtPriceAfterX96
        );

        return (response.base, response.quote);
    }

    //
    // EXTERNAL VIEW
    //

    //    /// @inheritdoc IClearingHousePerpdex
    //    function getQuoteToken() external view override returns (address) {
    //        return _quoteToken;
    //    }
    //
    //    /// @inheritdoc IClearingHousePerpdex
    //    function getUniswapV2Factory() external view override returns (address) {
    //        return _uniswapV2Factory;
    //    }

    /// @inheritdoc IClearingHousePerpdex
    function getClearingHouseConfig() external view override returns (address) {
        return _clearingHouseConfig;
    }

    /// @inheritdoc IClearingHousePerpdex
    function getInsuranceFund() external view override returns (address) {
        return _insuranceFund;
    }

    /// @inheritdoc IClearingHousePerpdex
    function getAccountValue(address trader) public view override returns (int256) {
        return AccountLibrary.getAccountValue(accountInfos[trader]);
    }

    //
    // INTERNAL NON-VIEW
    //

    //
    // INTERNAL VIEW
    //

    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }
}
