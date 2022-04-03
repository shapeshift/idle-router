// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.11;

interface IIdleCDO {
    function AATranche() external view returns (address);

    function BBTranche() external view returns (address);

    function token() external view returns (address);

    function depositAA(uint256 _amount) external returns (uint256);

    function depositBB(uint256 _amount) external returns (uint256);

    function withdrawAA(uint256 _amount) external returns (uint256);

    function withdrawBB(uint256 _amount) external returns (uint256);
}
