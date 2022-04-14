// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";

contract IdleRegistry is Ownable {
    mapping(address => bool) public isValidCdo;

    constructor() {}

    function setIdleCdo(address idleCdo) external onlyOwner {
        isValidCdo[idleCdo] = true;
    }
}
