// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IERC20Token is IERC20Upgradeable {
    /**
     * @dev mint
     * @param account address
     * @param amount count
     */
    function mint(address account, uint256 amount) external;

    /**
     * @dev burn token
     * @param amount count
     */
    function burn(uint256 amount) external;
}
