// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.7.6;
pragma abicoder v2;

interface IPerpdexRouter {
    function exchange() external view returns (address);

    function settlementToken() external view returns (address);

    function depositEth() external payable;

    function withdrawEth(uint256 amount) external;
}
