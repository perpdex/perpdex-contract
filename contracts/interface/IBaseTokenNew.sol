// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.7.6;

interface IBaseTokenNew {
    function shareToBalance(uint256 share) external view returns (uint256);

    function balanceToShare(uint256 balance) external view returns (uint256);
}
