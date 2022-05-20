// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import { IERC20Metadata } from "../interface/IERC20Metadata.sol";
import "./AccountLibrary.sol";
import "./PerpdexStructs.sol";

library VaultLibrary {
    struct DepositParams {
        address token;
        uint256 amount;
        address from;
    }

    struct WithdrawParams {
        address token;
        uint256 amount;
        address to;
    }

    function deposit(PerpdexStructs.AccountInfo storage accountInfo, DepositParams memory params) public {
        _transferTokenIn(params.token, params.from, params.amount);
        accountInfo.vaultInfo.collateralBalance = accountInfo.vaultInfo.collateralBalance.add(params.amount);
    }

    function withdraw(PerpdexStructs.AccountInfo storage accountInfo, WithdrawParams memory params) public {
        accountInfo.vaultInfo.collateralBalance = accountInfo.vaultInfo.collateralBalance.sub(params.amount);
        require(AccountLibrary.hasEnoughInitialMargin(accountInfo));

        SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(params.token), params.to, params.amount);
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
