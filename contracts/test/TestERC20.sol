// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import "@openzeppelin/contracts/proxy/Initializable.sol";
import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";

contract TestERC20 is ERC20PresetMinterPauser {
    uint256 _transferFeeRatio;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimal
    ) ERC20PresetMinterPauser(name, symbol) {
        _setupDecimals(decimal);
        _transferFeeRatio = 0;
    }

    function setMinter(address minter) external {
        grantRole(MINTER_ROLE, minter);
    }

    function burnWithoutApproval(address user, uint256 amount) external {
        _burn(user, amount);
    }

    function setTransferFeeRatio(uint256 ratio) external {
        _transferFeeRatio = ratio;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool success) {
        if (_transferFeeRatio != 0) {
            uint256 fee = (amount * _transferFeeRatio) / 100;
            _burn(sender, fee);
            amount = amount - fee;
        }
        return super.transferFrom(sender, recipient, amount);
    }
}
