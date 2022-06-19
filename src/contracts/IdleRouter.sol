// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.11;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../interfaces/IIdleRegistry.sol";
import "../interfaces/IIdleCDO.sol";
import "../interfaces/IIdleCDOTranche.sol";

contract IdleRouter is OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    event IdleRegistryUpdated(address newRegistry);

    address public idleRegistry;

    constructor() {}

    /**
     * @notice initialize contract and set the idleRegistry address
     * @param _idleRegistry address of the token-to-CDO registry
     */
    function initialize(address _idleRegistry) external initializer {
        OwnableUpgradeable.__Ownable_init();
        setIdleRegistry(_idleRegistry);
    }

    /**
     * @notice change the idleRegistry address
     * @param _idleRegistry new address of the token-to-CDO registry
     */
    function setIdleRegistry(address _idleRegistry) public onlyOwner {
        require(
            _idleRegistry != address(0) && _idleRegistry != idleRegistry,
            "IdleRouter: INVALID_ADDRESS"
        );
        idleRegistry = _idleRegistry;
        emit IdleRegistryUpdated(_idleRegistry);
    }

    /**
     * @notice deposit tokens into the AA CDO Tranche. Note: approvals must be made before
     * this call to allow the router to move your assets on your behalf
     * @param _cdo address of the CDO contract
     * @param _amount of the underlying token to deposit
     */
    function depositAA(address _cdo, uint256 _amount) external {
        _deposit(_cdo, _amount, true);
    }

    /**
     * @notice deposit tokens into the BB CDO Tranche. Note: approvals must be made before
     * this call to allow the router to move your assets on your behalf
     * @param _cdo address of the CDO contract
     * @param _amount of the underlying token to deposit
     */
    function depositBB(address _cdo, uint256 _amount) external {
        _deposit(_cdo, _amount, false);
    }

    /**
     * @notice burn AA Tranche tokens and get the principal + interest back. Note: approvals
     * must be made before this call to allow the router to move your assets on your behalf
     * @param _trancheTokenAA the CDO AA Tranche token address
     * @param _amount of the AA Tranche token to burn
     */
    function withdrawAA(address _trancheTokenAA, uint256 _amount) external {
        _withdraw(_trancheTokenAA, _amount, true);
    }

    /**
     * @notice burn BB Tranche tokens and get the principal + interest back. Note: approvals
     * must be made before this call to allow the router to move your assets on your behalf
     * @param _trancheTokenBB the CDO BB Tranche token address
     * @param _amount of the BB Tranche token to burn
     */
    function withdrawBB(address _trancheTokenBB, uint256 _amount) external {
        _withdraw(_trancheTokenBB, _amount, false);
    }

    /**
     * @notice base function for depositing tokens into the CDO Tranches. Note: approvals
     * must be made before this call to allow the router to move your assets on your behalf
     * @param _cdo address of the CDO contract
     * @param _amount of the underlying token to deposit
     * @param _isAATranche set to true to deposit into an AA Tranche,
     * set to false to deposit into a BB Tranche
     */
    function _deposit(
        address _cdo,
        uint256 _amount,
        bool _isAATranche
    ) internal {
        require(
            IIdleRegistry(idleRegistry).isValidCdo(_cdo),
            "IdleRouter: INVALID_CDO"
        );
        require(_amount != 0, "IdleRouter: INVALID_AMOUNT");
        IIdleCDO idleCdo = IIdleCDO(_cdo);
        address tokenAddress = idleCdo.token();

        IERC20Upgradeable trancheToken = IERC20Upgradeable(
            _isAATranche ? idleCdo.AATranche() : idleCdo.BBTranche()
        );

        IERC20Upgradeable underlyingToken = IERC20Upgradeable(tokenAddress);

        uint256 trancheTokenBalanceBefore = trancheToken.balanceOf(
            address(this)
        );
        uint256 underlyingTokenBalanceBefore = underlyingToken.balanceOf(
            address(this)
        );

        underlyingToken.safeTransferFrom(msg.sender, address(this), _amount);

        if (underlyingToken.allowance(address(this), _cdo) < _amount) {
            // Avoid issues with some tokens requiring 0
            underlyingToken.safeApprove(_cdo, 0);
            underlyingToken.safeApprove(_cdo, type(uint256).max);
        }

        uint256 qtyMinted = _isAATranche
            ? idleCdo.depositAA(_amount)
            : idleCdo.depositBB(_amount);
        trancheToken.safeTransfer(msg.sender, qtyMinted);

        assert(
            trancheTokenBalanceBefore ==
                trancheToken.balanceOf(address(this)) &&
                underlyingTokenBalanceBefore ==
                underlyingToken.balanceOf(address(this))
        );
    }

    /**
     * @notice base function for withdrawing the underlying with interest. Note: approvals
     * must be made before this call to allow the router to move your assets on your behalf
     * @param _trancheTokenAddress the CDO Tranche token address
     * @param _amount of the Tranche token token to burn
     * @param _isAATranche set to true to withdraw from an AA Tranche,
     * set to false to withdraw from a BB Tranche
     */
    function _withdraw(
        address _trancheTokenAddress,
        uint256 _amount,
        bool _isAATranche
    ) internal {
        address idleCDOAddress = IIdleCDOTranche(_trancheTokenAddress).minter();
        require(
            IIdleRegistry(idleRegistry).isValidCdo(idleCDOAddress),
            "IdleRouter: INVALID_CDO"
        );

        IIdleCDO idleCdo = IIdleCDO(idleCDOAddress);
        IERC20Upgradeable trancheToken = IERC20Upgradeable(
            _trancheTokenAddress
        );
        IERC20Upgradeable underlyingToken = IERC20Upgradeable(idleCdo.token());

        uint256 trancheTokenBalanceBefore = trancheToken.balanceOf(
            address(this)
        );
        uint256 underlyingTokenBalanceBefore = underlyingToken.balanceOf(
            address(this)
        );

        if (_amount == 0) {
            // Idle treats zero as a special value.
            _amount = trancheToken.balanceOf(msg.sender);
        }

        trancheToken.transferFrom(msg.sender, address(this), _amount);

        // Note: no approval required for withdrawal!
        uint256 amountToReturn = _isAATranche
            ? idleCdo.withdrawAA(_amount)
            : idleCdo.withdrawBB(_amount);

        underlyingToken.transfer(msg.sender, amountToReturn);

        assert(
            trancheTokenBalanceBefore ==
                trancheToken.balanceOf(address(this)) &&
                underlyingTokenBalanceBefore ==
                underlyingToken.balanceOf(address(this))
        );
    }
}
