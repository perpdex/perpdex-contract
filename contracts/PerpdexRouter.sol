// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;
pragma abicoder v2;

import { IWETH9 } from "./interface/external/IWETH9.sol";
import { IPerpdexExchange } from "./interface/IPerpdexExchange.sol";
import { IPerpdexRouter } from "./interface/IPerpdexRouter.sol";

// immutable, storage immutable
contract PerpdexRouter is IPerpdexRouter {
    // config
    address public immutable override exchange;
    address public immutable override settlementToken;

    constructor(address exchangeArg) {
        exchange = exchangeArg;
        settlementToken = IPerpdexExchange(exchangeArg).settlementToken();
    }

    function depositEth() external payable override {
        uint256 amount = msg.value;
        IWETH9(settlementToken).deposit{ value: amount }();
        IPerpdexExchange(exchange).deposit(amount);
    }

    function withdrawEth(uint256 amount) external override {
        IPerpdexExchange(exchange).withdraw(amount);
        require(IWETH9(settlementToken).transfer(msg.sender, amount));
    }
}
