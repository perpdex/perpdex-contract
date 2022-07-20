// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.7.6;
pragma abicoder v2;

import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import { SignedSafeMath } from "@openzeppelin/contracts/utils/math/SignedSafeMath.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { PerpMath } from "./PerpMath.sol";
import { IERC20Metadata } from "../interface/IERC20Metadata.sol";
import { AccountLibrary } from "./AccountLibrary.sol";
import { PerpdexStructs } from "./PerpdexStructs.sol";

library VaultLibrary {
    using PerpMath for int256;
    using SafeCast for uint256;
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
        address payable to;
        uint24 imRatio;
    }

    function deposit(PerpdexStructs.AccountInfo storage accountInfo, DepositParams memory params) internal {
        require(params.amount > 0, "VL_D: zero amount");
        _transferTokenIn(params.settlementToken, params.from, params.amount);
        uint256 collateralAmount =
            _toCollateralAmount(params.amount, IERC20Metadata(params.settlementToken).decimals());
        accountInfo.vaultInfo.collateralBalance = accountInfo.vaultInfo.collateralBalance.add(
            collateralAmount.toInt256()
        );
    }

    function depositEth(PerpdexStructs.AccountInfo storage accountInfo, uint256 amount) internal {
        require(amount > 0, "VL_DE: zero amount");
        accountInfo.vaultInfo.collateralBalance = accountInfo.vaultInfo.collateralBalance.add(amount.toInt256());
    }

    function withdraw(PerpdexStructs.AccountInfo storage accountInfo, WithdrawParams memory params) internal {
        require(params.amount > 0, "VL_W: zero amount");

        uint256 collateralAmount =
            params.settlementToken == address(0)
                ? params.amount
                : _toCollateralAmount(params.amount, IERC20Metadata(params.settlementToken).decimals());
        accountInfo.vaultInfo.collateralBalance = accountInfo.vaultInfo.collateralBalance.sub(
            collateralAmount.toInt256()
        );

        require(AccountLibrary.hasEnoughInitialMargin(accountInfo, params.imRatio), "VL_W: not enough initial margin");

        if (params.settlementToken == address(0)) {
            params.to.transfer(params.amount);
        } else {
            SafeERC20.safeTransfer(IERC20(params.settlementToken), params.to, params.amount);
        }
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
        SafeERC20.safeTransferFrom(IERC20(token), from, address(this), amount);
        require(
            (IERC20Metadata(token).balanceOf(address(this)).sub(balanceBefore)) == amount,
            "VL_TTI: inconsistent balance"
        );
    }

    function _toCollateralAmount(uint256 amount, uint8 tokenDecimals) private pure returns (uint256) {
        int256 decimalsDiff = int256(18).sub(uint256(tokenDecimals).toInt256());
        uint256 decimalsDiffAbs = decimalsDiff.abs();
        require(decimalsDiffAbs <= 77, "VL_TCA: too large decimals diff");
        return decimalsDiff >= 0 ? amount.mul(10**decimalsDiffAbs) : amount.div(10**decimalsDiffAbs);
    }
}
