// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";

contract IdleRegistry is Ownable {
    mapping(address => address) public tokenToIdleCDO;

    constructor() {}

    function addIdleCDO(address underlyingToken, address idleCDO)
        external
        onlyOwner
    {
        tokenToIdleCDO[underlyingToken] = idleCDO;
    }
}
