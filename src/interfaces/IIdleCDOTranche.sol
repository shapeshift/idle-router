// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.11;

interface IIdleCDOTranche {
    // the Idle CDO is the minter.
    function minter() external view returns (address);
}
