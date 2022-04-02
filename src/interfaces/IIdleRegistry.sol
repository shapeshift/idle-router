// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.11;

abstract contract IIdleRegistry {
    mapping(address => address) public tokenToIdleCDO;
}
