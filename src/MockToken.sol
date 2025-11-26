// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    uint8 private _customDecimals;
    
    constructor(
        string memory name,
        string memory symbol, 
        uint8 tokenDecimals,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        _customDecimals = tokenDecimals;
        _mint(msg.sender, initialSupply * 10 ** tokenDecimals);
    }

    function decimals() public view virtual override returns (uint8) {
        return _customDecimals;
    }

    /// @notice Faucet: mint token buat testing (bisa dipanggil siapa aja)
    function faucet(uint256 amount) external {
        _mint(msg.sender, amount * 10 ** _customDecimals);
    }

    /// @notice Faucet dengan recipient spesifik (buat testing escrow)
    function faucetTo(address recipient, uint256 amount) external {
        _mint(recipient, amount * 10 ** _customDecimals);
    }

    /// @notice Burn tokens (buat testing cancel/refund)
    function burn(uint256 amount) external {
        _burn(msg.sender, amount * 10 ** _customDecimals);
    }
}