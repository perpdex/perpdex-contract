// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { AddressUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20Metadata } from "./interface/IERC20Metadata.sol";
import { IClearingHousePerpdexNew } from "./interface/IClearingHousePerpdexNew.sol";
import { PerpdexStructs } from "./lib/PerpdexStructs.sol";
import { AccountLibrary } from "./lib/AccountLibrary.sol";
import { MakerLibrary } from "./lib/MakerLibrary.sol";
import { TakerLibrary } from "./lib/TakerLibrary.sol";
import { VaultLibrary } from "./lib/VaultLibrary.sol";
import { PerpMath } from "./lib/PerpMath.sol";
import { PerpSafeCast } from "./lib/PerpSafeCast.sol";
import { QuoteTokenPerpdex } from "./QuoteTokenPerpdex.sol";

// never inherit any new stateful contract. never change the orders of parent stateful contracts
contract ClearingHousePerpdexNew is IClearingHousePerpdexNew, ReentrancyGuard, Ownable {
    using AddressUpgradeable for address;
    using PerpMath for uint256;
    using PerpSafeCast for uint256;

    // states
    // trader
    mapping(address => PerpdexStructs.AccountInfo) public accountInfos;
    // baseToken
    mapping(address => PerpdexStructs.PriceLimitInfo) public priceLimitInfos;
    PerpdexStructs.InsuranceFundInfo public insuranceFundInfo;

    // config
    address public immutable quoteToken;
    address public immutable uniV2Factory;
    PerpdexStructs.PriceLimitConfig public priceLimitConfig;
    uint8 public maxMarketsPerAccount;
    uint24 public imRatio;
    uint24 public mmRatio;
    uint24 public liquidationRewardRatio;
    uint24 public maxFundingRateRatio;
    mapping(address => bool) public isBaseTokenAllowed;

    //
    // MODIFIER
    //

    //
    // EXTERNAL NON-VIEW
    //

    constructor(
        string memory quoteTokenName,
        string memory quoteTokenSymbol,
        address uniV2FactoryArg
    ) public {
        // CH_UANC: UniV2Factory address is not contract
        require(uniV2FactoryArg.isContract(), "CH_UANC");

        quoteToken = address(new QuoteTokenPerpdex{ salt: 0 }(quoteTokenName, quoteTokenSymbol, address(this)));
        uniV2Factory = uniV2FactoryArg;

        priceLimitConfig.priceLimitLiquidationRatio = 10e4;
        priceLimitConfig.priceLimitLiquidationRatio = 5e4;
        maxMarketsPerAccount = 16;
        imRatio = 10e4;
        mmRatio = 5e4;
        liquidationRewardRatio = 20e4;
        maxFundingRateRatio = 5e4;
    }

    function deposit(address token, uint256 amount) external override nonReentrant {
        address trader = _msgSender();
        VaultLibrary.deposit(
            accountInfos[trader],
            VaultLibrary.DepositParams({ quoteToken: quoteToken, amount: amount, from: trader })
        );
    }

    function withdraw(address token, uint256 amount) external override nonReentrant {
        address trader = _msgSender();
        VaultLibrary.withdraw(
            accountInfos[trader],
            VaultLibrary.WithdrawParams({
                quoteToken: quoteToken,
                amount: amount,
                to: trader,
                poolFactory: uniV2Factory,
                imRatio: imRatio
            })
        );
    }

    /// @inheritdoc IClearingHousePerpdexNew
    function openPosition(OpenPositionParams calldata params)
        external
        override
        nonReentrant
        returns (int256 base, int256 quote)
    {
        address trader = _msgSender();

        TakerLibrary.OpenPositionResponse memory response =
            TakerLibrary.openPosition(
                accountInfos[trader],
                priceLimitInfos[params.baseToken],
                TakerLibrary.OpenPositionParams({
                    baseToken: params.baseToken,
                    quoteToken: quoteToken,
                    isBaseToQuote: params.isBaseToQuote,
                    isExactInput: params.isExactInput,
                    amount: params.amount,
                    oppositeAmountBound: params.oppositeAmountBound,
                    deadline: params.deadline,
                    poolFactory: uniV2Factory,
                    priceLimitConfig: priceLimitConfig,
                    isBaseTokenAllowed: isBaseTokenAllowed[params.baseToken],
                    mmRatio: mmRatio,
                    imRatio: imRatio,
                    maxMarketsPerAccount: maxMarketsPerAccount
                })
            );

        emit PositionChanged(
            trader,
            params.baseToken,
            response.exchangedBase,
            response.exchangedQuote,
            accountInfos[trader].takerInfo[params.baseToken].quoteBalance,
            response.realizedPnL,
            response.priceAfterX96
        );

        return (response.exchangedBase, response.exchangedQuote);
    }

    /// @inheritdoc IClearingHousePerpdexNew
    function liquidate(LiquidateParams calldata params)
        external
        override
        nonReentrant
        returns (int256 base, int256 quote)
    {
        address trader = params.trader;
        address liquidator = _msgSender();

        TakerLibrary.LiquidateResponse memory response =
            TakerLibrary.liquidate(
                accountInfos[trader],
                accountInfos[liquidator],
                priceLimitInfos[params.baseToken],
                insuranceFundInfo,
                TakerLibrary.LiquidateParams({
                    baseToken: params.baseToken,
                    quoteToken: quoteToken,
                    amount: params.amount,
                    oppositeAmountBound: params.oppositeAmountBound,
                    deadline: params.deadline,
                    poolFactory: uniV2Factory,
                    priceLimitConfig: priceLimitConfig,
                    mmRatio: mmRatio,
                    liquidationRewardRatio: liquidationRewardRatio,
                    maxMarketsPerAccount: maxMarketsPerAccount
                })
            );

        emit PositionChanged(
            trader,
            params.baseToken,
            response.exchangedBase,
            response.exchangedQuote,
            accountInfos[trader].takerInfo[params.baseToken].quoteBalance,
            response.realizedPnL,
            response.priceAfterX96
        );

        return (response.exchangedBase, response.exchangedQuote);
    }

    /// @inheritdoc IClearingHousePerpdexNew
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
                MakerLibrary.AddLiquidityParams({
                    baseToken: params.baseToken,
                    quoteToken: quoteToken,
                    base: params.base,
                    quote: params.quote,
                    minBase: params.minBase,
                    minQuote: params.minQuote,
                    deadline: params.deadline,
                    poolFactory: uniV2Factory,
                    isBaseTokenAllowed: isBaseTokenAllowed[params.baseToken],
                    imRatio: imRatio,
                    maxMarketsPerAccount: maxMarketsPerAccount
                })
            );

        emit LiquidityChanged(
            maker,
            params.baseToken,
            quoteToken,
            response.base.toInt256(),
            response.quote.toInt256(),
            response.liquidity.toInt256()
        );

        return AddLiquidityResponse({ base: response.base, quote: response.quote, liquidity: response.liquidity });
    }

    /// @inheritdoc IClearingHousePerpdexNew
    function removeLiquidity(RemoveLiquidityParams calldata params)
        external
        override
        returns (RemoveLiquidityResponse memory)
    {
        return removeLiquidity(params, _msgSender());
    }

    /// @inheritdoc IClearingHousePerpdexNew
    function removeLiquidity(RemoveLiquidityParams calldata params, address maker)
        public
        override
        nonReentrant
        returns (RemoveLiquidityResponse memory)
    {
        MakerLibrary.RemoveLiquidityResponse memory response =
            MakerLibrary.removeLiquidity(
                accountInfos[maker],
                MakerLibrary.RemoveLiquidityParams({
                    baseToken: params.baseToken,
                    quoteToken: quoteToken,
                    liquidity: params.liquidity,
                    minBase: params.minBase,
                    minQuote: params.minQuote,
                    deadline: params.deadline,
                    poolFactory: uniV2Factory,
                    makerIsSender: maker == _msgSender(),
                    mmRatio: mmRatio,
                    maxMarketsPerAccount: maxMarketsPerAccount
                })
            );

        emit LiquidityChanged(
            maker,
            params.baseToken,
            quoteToken,
            response.base.neg256(),
            response.quote.neg256(),
            params.liquidity.neg256()
        );

        emit PositionChanged(
            maker,
            params.baseToken,
            response.takerBase, // exchangedPositionSize
            response.takerQuote, // exchangedPositionNotional
            accountInfos[maker].takerInfo[params.baseToken].quoteBalance,
            response.realizedPnL, // realizedPnl
            response.priceAfterX96
        );

        return RemoveLiquidityResponse({ base: response.base, quote: response.quote });
    }

    function setPriceLimitConfig(PerpdexStructs.PriceLimitConfig calldata value)
        external
        override
        onlyOwner
        nonReentrant
    {
        priceLimitConfig = value;
    }

    function setMaxMarketsPerAccount(uint8 value) external override onlyOwner nonReentrant {
        maxMarketsPerAccount = value;
    }

    function setImRatio(uint24 value) external override onlyOwner nonReentrant {
        require(value < 1e6);
        require(value >= mmRatio);
        imRatio = value;
    }

    function setMmRatio(uint24 value) external override onlyOwner nonReentrant {
        require(value <= imRatio);
        require(value > 0);
        mmRatio = value;
    }

    function setLiquidationRewardRatio(uint24 value) external override onlyOwner nonReentrant {
        require(value < 1e6);
        liquidationRewardRatio = value;
    }

    function setMaxFundingRateRatio(uint24 value) external override onlyOwner nonReentrant {
        require(value < 1e6);
        maxFundingRateRatio = value;
    }

    function setIsBaseTokenAllowed(address baseToken, bool value) external override onlyOwner nonReentrant {
        isBaseTokenAllowed[baseToken] = value;
    }

    //
    // EXTERNAL VIEW
    //

    // all raw information can be retrieved through getters (including default getters)

    function getTakerInfo(address trader, address baseToken) external returns (PerpdexStructs.TakerInfo memory) {
        return accountInfos[trader].takerInfo[baseToken];
    }

    function getMakerInfo(address trader, address baseToken) external returns (PerpdexStructs.MakerInfo memory) {
        return accountInfos[trader].makerInfo[baseToken];
    }

    // convenient getters

    function getTotalAccountValue(address trader) external view override returns (int256) {
        return AccountLibrary.getTotalAccountValue(accountInfos[trader], uniV2Factory, quoteToken);
    }

    function getPositionSize(address trader, address baseToken) external view override returns (int256) {
        return AccountLibrary.getPositionSize(accountInfos[trader], uniV2Factory, baseToken, quoteToken);
    }

    function getPositionNotional(address trader, address baseToken) external view override returns (int256) {
        return AccountLibrary.getPositionNotional(accountInfos[trader], uniV2Factory, baseToken, quoteToken);
    }

    function getTotalPositionNotional(address trader) external view override returns (uint256) {
        return AccountLibrary.getTotalPositionNotional(accountInfos[trader], uniV2Factory, quoteToken);
    }

    function getOpenPositionSize(address trader, address baseToken) external view override returns (uint256) {
        return AccountLibrary.getOpenPositionSize(accountInfos[trader], uniV2Factory, baseToken, quoteToken);
    }

    function getOpenPositionNotional(address trader, address baseToken) external view override returns (uint256) {
        return AccountLibrary.getOpenPositionNotional(accountInfos[trader], uniV2Factory, baseToken, quoteToken);
    }

    function getTotalOpenPositionNotional(address trader) external view override returns (uint256) {
        return AccountLibrary.getTotalOpenPositionNotional(accountInfos[trader], uniV2Factory, quoteToken);
    }

    function hasEnoughMaintenanceMargin(address trader) external view override returns (bool) {
        return AccountLibrary.hasEnoughMaintenanceMargin(accountInfos[trader], uniV2Factory, quoteToken, mmRatio);
    }

    function hasEnoughInitialMargin(address trader) external view override returns (bool) {
        return AccountLibrary.hasEnoughInitialMargin(accountInfos[trader], uniV2Factory, quoteToken, imRatio);
    }

    //
    // INTERNAL NON-VIEW
    //

    //
    // INTERNAL VIEW
    //
}
