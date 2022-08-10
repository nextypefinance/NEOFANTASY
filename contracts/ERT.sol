// SPDX-License-Identifier: MIT
pragma solidity 0.6.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


/// @author matt lee
contract ERT is ERC20, Ownable {

    /**
     * @dev Sets the {name} and {symbol} of token.
     * Initializes {decimals} with a default value of 18.
     * Mints all tokens.
     * Transfers ownership to another account. So, the token creator will not be counted as an owner.
     */
    constructor() public ERC20("Eternal Rock Token", "ERT") {
        uint256 supply = 250000000 * (10 ** 18);

        _mint(_msgSender(), supply);

    }
}