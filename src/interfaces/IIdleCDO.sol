// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.11;
abstract contract IIdleCDO {
    address public AATranche;
    function depositAA(uint256 _amount) external virtual returns (uint256);
    function depositBB(uint256 _amount) external virtual returns (uint256);
    function withdrawAA(uint256 _amount) external virtual returns (uint256);
    function withdrawBB(uint256 _amount) external  virtual returns (uint256);
}