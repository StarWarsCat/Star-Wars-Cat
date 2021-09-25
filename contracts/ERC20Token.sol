// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";


contract ERC20Token is ERC20Upgradeable {

    function __ERC20Token_init() public initializer {
        __ERC20_init("Star Wars Cat", "SWCAT");

        _mint(msg.sender, 100 * 10**8 * 10**decimals());
    }

    function decimals() public view override returns (uint8) {
        return 18;
    }

}
