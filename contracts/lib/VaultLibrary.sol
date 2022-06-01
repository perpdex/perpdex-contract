// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { SignedSafeMath } from "@openzeppelin/contracts/math/SignedSafeMath.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import { IERC20Metadata } from "../interface/IERC20Metadata.sol";
import { PerpSafeCast } from "./PerpSafeCast.sol";
import { AccountLibrary } from "./AccountLibrary.sol";
import { PerpdexStructs } from "./PerpdexStructs.sol";

library VaultLibrary {
    using PerpSafeCast for uint256;
    using SafeMath for uint256;
    using SignedSafeMath for int256;

    struct DepositParams {
        address settlementToken;
        uint256 amount;
        address from;
    }

    struct WithdrawParams {
        address settlementToken;
        uint256 amount;
        address to;
        uint24 imRatio;
    }

    function deposit(PerpdexStructs.AccountInfo storage accountInfo, DepositParams memory params) internal {
        // V_ZA: Zero amount
        require(params.amount > 0, "V_ZA");
        _transferTokenIn(params.settlementToken, params.from, params.amount);
        accountInfo.vaultInfo.collateralBalance = accountInfo.vaultInfo.collateralBalance.add(params.amount.toInt256());
    }

    function withdraw(PerpdexStructs.AccountInfo storage accountInfo, WithdrawParams memory params) internal {
        // V_ZA: Zero amount
        require(params.amount > 0, "V_ZA");
        accountInfo.vaultInfo.collateralBalance = accountInfo.vaultInfo.collateralBalance.sub(params.amount.toInt256());
        require(AccountLibrary.hasEnoughInitialMargin(accountInfo, params.imRatio));

        SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(params.settlementToken), params.to, params.amount);
    }

    function transferInsuranceFund(
        PerpdexStructs.AccountInfo storage accountInfo,
        PerpdexStructs.InsuranceFundInfo storage insuranceFundInfo,
        uint256 amount
    ) internal {
        accountInfo.vaultInfo.collateralBalance = accountInfo.vaultInfo.collateralBalance.add(amount.toInt256());
        insuranceFundInfo.balance = insuranceFundInfo.balance.sub(amount.toInt256());
        require(insuranceFundInfo.balance >= 0);
    }

    function transferProtocolFee(
        PerpdexStructs.AccountInfo storage accountInfo,
        PerpdexStructs.ProtocolInfo storage protocolInfo,
        uint256 amount
    ) internal {
        accountInfo.vaultInfo.collateralBalance = accountInfo.vaultInfo.collateralBalance.add(amount.toInt256());
        protocolInfo.protocolFee = protocolInfo.protocolFee.sub(amount);
    }

    function _transferTokenIn(
        address token,
        address from,
        uint256 amount
    ) private {
        // check for deflationary tokens by assuring balances before and after transferring to be the same
        uint256 balanceBefore = IERC20Metadata(token).balanceOf(address(this));
        SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(token), from, address(this), amount);
        // V_IBA: inconsistent balance amount, to prevent from deflationary tokens
        require((IERC20Metadata(token).balanceOf(address(this)).sub(balanceBefore)) == amount, "V_IBA");
    }
}
