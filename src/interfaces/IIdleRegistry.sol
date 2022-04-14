// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.11;

interface IIdleRegistry {
    function isValidCdo(address idleCdo) external view returns (bool);
}
