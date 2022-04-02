// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.11;

interface IIdleRegistry {
    function tokenToIdleCDO(address underlyingToken) external view returns (address);
}
