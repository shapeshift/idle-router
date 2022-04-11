// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";

contract IdleRegistry is Ownable {
    mapping(address => address) public idleCdoToToken;

    constructor() {}

    function setIdleCdo(address idleCdo, address underlyingToken)
        external
        onlyOwner
    {
        idleCdoToToken[idleCdo] = underlyingToken;
    }

    function isValidCdo(address _cdo) external view returns (bool) {
        return idleCdoToToken[_cdo] != address(0);
    }
}
