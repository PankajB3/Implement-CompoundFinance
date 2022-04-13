// SPDX-License-Identifier:MIT

pragma solidity >= 0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BAT is ERC20{
    constructor() ERC20("BAT","BTKN"){}

    function mint(address to, uint256 amt) external{
        _mint(to, amt);
    }
}