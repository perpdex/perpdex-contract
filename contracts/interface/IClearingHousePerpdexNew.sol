// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.7.6;
pragma abicoder v2;

import { PerpdexStructs } from "../lib/PerpdexStructs.sol";

interface IClearingHousePerpdexNew {
    struct AddLiquidityParams {
        address baseToken;
        uint256 base;
        uint256 quote;
        uint256 minBase;
        uint256 minQuote;
        uint256 deadline;
    }

    struct RemoveLiquidityParams {
        address baseToken;
        uint256 liquidity;
        uint256 minBase;
        uint256 minQuote;
        uint256 deadline;
    }

    struct AddLiquidityResponse {
        uint256 base;
        uint256 quote;
        uint256 liquidity;
    }

    struct RemoveLiquidityResponse {
        uint256 base;
        uint256 quote;
    }

    /// @param oppositeAmountBound
    // B2Q + exact input, want more output quote as possible, so we set a lower bound of output quote
    // B2Q + exact output, want less input base as possible, so we set a upper bound of input base
    // Q2B + exact input, want more output base as possible, so we set a lower bound of output base
    // Q2B + exact output, want less input quote as possible, so we set a upper bound of input quote
    // when it's set to 0, it will disable slippage protection entirely regardless of exact input or output
    // when it's over or under the bound, it will be reverted
    /// @param sqrtPriceLimitX96
    // B2Q: the price cannot be less than this value after the swap
    // Q2B: the price cannot be greater than this value after the swap
    // it will fill the trade until it reaches the price limit but WON'T REVERT
    // when it's set to 0, it will disable price limit;
    // when it's 0 and exact output, the output amount is required to be identical to the param amount
    struct OpenPositionParams {
        address baseToken;
        bool isBaseToQuote;
        bool isExactInput;
        uint256 amount;
        uint256 oppositeAmountBound;
        uint256 deadline;
    }

    struct LiquidateParams {
        address trader;
        address baseToken;
        uint256 amount;
        uint256 oppositeAmountBound;
        uint256 deadline;
    }

    /// @notice Emitted when taker position is being liquidated
    /// @param trader The trader who has been liquidated
    /// @param baseToken Virtual base token(ETH, BTC, etc...) address
    /// @param positionNotional The cost of position
    /// @param positionSize The size of position
    /// @param liquidationFee The fee of liquidate
    /// @param liquidator The address of liquidator
    event PositionLiquidated(
        address indexed trader,
        address indexed baseToken,
        uint256 positionNotional,
        uint256 positionSize,
        uint256 liquidationFee,
        address liquidator
    );

    /// @notice Emitted when maker's liquidity of a order changed
    /// @param maker The one who provide liquidity
    /// @param baseToken The address of virtual base token(ETH, BTC, etc...)
    /// @param quoteToken The address of virtual USD token
    /// @param base The amount of base token added (> 0) / removed (< 0) as liquidity; fees not included
    /// @param quote The amount of quote token added ... (same as the above)
    /// @param liquidity The amount of liquidity unit added (> 0) / removed (< 0)
    event LiquidityChanged(
        address indexed maker,
        address indexed baseToken,
        address indexed quoteToken,
        int256 base,
        int256 quote,
        int256 liquidity
    );

    /// @notice Emitted when taker's position is being changed
    /// @param trader Trader address
    /// @param baseToken The address of virtual base token(ETH, BTC, etc...)
    /// @param exchangedPositionSize The actual amount swap to uniswapV3 pool
    /// @param exchangedPositionNotional The cost of position, include fee
    /// @param openNotional The cost of open/close position, < 0: long, > 0: short
    /// @param realizedPnl The realized Pnl after open/close position
    /// @param priceAfterX96 The price after swap, in X96
    event PositionChanged(
        address indexed trader,
        address indexed baseToken,
        int256 exchangedPositionSize,
        int256 exchangedPositionNotional,
        int256 openNotional,
        int256 realizedPnl,
        uint256 priceAfterX96
    );

    function deposit(address token, uint256 amount) external;

    function withdraw(address token, uint256 amount) external;

    /// @notice Maker can call `addLiquidity` to provide liquidity on Uniswap V3 pool
    /// @dev Tx will fail if adding `base == 0 && quote == 0` / `liquidity == 0`
    /// @dev - `AddLiquidityParams.useTakerBalance` is only accept `false` now
    /// @param params AddLiquidityParams struct
    /// @return response AddLiquidityResponse struct
    function addLiquidity(AddLiquidityParams calldata params) external returns (AddLiquidityResponse memory);

    /// @notice Maker can call `removeLiquidity` to remove liquidity
    /// @dev remove liquidity will transfer maker impermanent position to taker position,
    /// if `liquidity` of RemoveLiquidityParams struct is zero, the action will collect fee from
    /// pool to maker
    /// @param params RemoveLiquidityParams struct
    /// @return response RemoveLiquidityResponse struct
    function removeLiquidity(RemoveLiquidityParams calldata params)
        external
        returns (RemoveLiquidityResponse memory response);

    function removeLiquidity(RemoveLiquidityParams calldata params, address maker)
        external
        returns (RemoveLiquidityResponse memory response);

    /// @notice Trader can call `openPosition` to long/short on baseToken market
    /// @dev - `OpenPositionParams.oppositeAmountBound`
    ///     - B2Q + exact input, want more output quote as possible, so we set a lower bound of output quote
    ///     - B2Q + exact output, want less input base as possible, so we set a upper bound of input base
    ///     - Q2B + exact input, want more output base as possible, so we set a lower bound of output base
    ///     - Q2B + exact output, want less input quote as possible, so we set a upper bound of input quote
    ///     > when it's set to 0, it will disable slippage protection entirely regardless of exact input or output
    ///     > when it's over or under the bound, it will be reverted
    /// @dev - `OpenPositionParams.sqrtPriceLimitX96`
    ///     - B2Q: the price cannot be less than this value after the swap
    ///     - Q2B: the price cannot be greater than this value after the swap
    ///     > it will fill the trade until it reaches the price limit but WON'T REVERT
    ///     > when it's set to 0, it will disable price limit;
    ///     > when it's 0 and exact output, the output amount is required to be identical to the param amount
    /// @param params OpenPositionParams struct
    /// @return base The amount of baseToken the taker got or spent
    /// @return quote The amount of quoteToken the taker got or spent
    function openPosition(OpenPositionParams calldata params) external returns (int256 base, int256 quote);

    /// @notice If trader is underwater, any one can call `liquidate` to liquidate this trader
    /// @dev If trader has open orders, need to call `cancelAllExcessOrders` first
    /// @return base The amount of baseToken the taker got or spent
    /// @return quote The amount of quoteToken the taker got or spent
    function liquidate(LiquidateParams calldata params) external returns (int256 base, int256 quote);

    function setPriceLimitConfig(PerpdexStructs.PriceLimitConfig calldata value) external;

    function setMaxMarketsPerAccount(uint8 value) external;

    function setImRatio(uint24 value) external;

    function setMmRatio(uint24 value) external;

    function setLiquidationRewardRatio(uint24 value) external;

    function setTwapInterval(uint32 value) external;

    function setMaxFundingRateRatio(uint24 value) external;

    function setIsBaseTokenAllowed(address baseToken, bool value) external;

    function getTotalAccountValue(address trader) external view returns (int256);

    function getPositionSize(address trader, address baseToken) external view returns (int256);

    function getPositionNotional(address trader, address baseToken) external view returns (int256);

    function getTotalPositionNotional(address trader) external view returns (uint256);

    function getOpenPositionSize(address trader, address baseToken) external view returns (uint256);

    function getOpenPositionNotional(address trader, address baseToken) external view returns (uint256);

    function getTotalOpenPositionNotional(address trader) external view returns (uint256);

    function hasEnoughMaintenanceMargin(address trader) external view returns (bool);

    function hasEnoughInitialMargin(address trader) external view returns (bool);
}
