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
    event TokensDeposited(
        address indexed user,
        address indexed token,
        address indexed trancheToken,
        uint256 amountOfTokenDeposited
    );
    event TokensWithdrew(
        address indexed user,
        address indexed token,
        address indexed trancheToken,
        uint256 amountOfTrancheTokenWithdrew
    );

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
     * @param _token the underlying token for the CDO
     * @param _amount of the underlying token to deposit
     */
    function depositAA(address _token, uint256 _amount) external {
        _deposit(_token, _amount, true);
    }

    /**
     * @notice deposit tokens into the AA CDO Tranche. Note: approvals must be made before
     * this call to allow the router to move your assets on your behalf
     * @param _token the underlying token for the CDO
     * @param _amount of the underlying token to deposit
     */
    function depositBB(address _token, uint256 _amount) external {
        _deposit(_token, _amount, false);
    }

    /**
     * @notice burn AA Tranche tokens and get the principal + interest back
     * @param _amount of the AA Tranche token to burn
     */
    function withdrawAA(address _trancheTokenAA, uint256 _amount) external {
        _withdraw(_trancheTokenAA, _amount, true);
    }

    /**
     * @notice burn BB Tranche tokens and get the principal + interest back
     * @param _amount of the BB Tranche token to burn
     */
    function withdrawBB(address _trancheTokenBB, uint256 _amount) external {
        _withdraw(_trancheTokenBB, _amount, false);
    }

    /**
     * @notice base function for depositing tokens into the CDO Tranches. Note: approvals
     * must be made before this call to allow the router to move your assets on your behalf
     * @param _token the underlying token for the CDO
     * @param _amount of the underlying token to deposit
     * @param isAATranche set to true to deposit into an AA Tranche,
     * set to false to deposit into a BB Tranche 
     */
    function _deposit(
        address _token,
        uint256 _amount,
        bool isAATranche
    ) internal {
        address idleCDOAddress = IIdleRegistry(idleRegistry).tokenToIdleCDO(
            _token
        );
        require(idleCDOAddress != address(0), "IdleRouter: INVALID_TOKEN");
        require(_amount != 0, "IdleRouter: INVALID_AMOUNT");

        IIdleCDO idleCdo = IIdleCDO(idleCDOAddress);
        IERC20Upgradeable trancheToken = IERC20Upgradeable(
            isAATranche ? idleCdo.AATranche() : idleCdo.BBTranche()
        );

        IERC20Upgradeable underlyingToken = IERC20Upgradeable(_token);

        uint256 trancheTokenBalanceBefore = trancheToken.balanceOf(
            address(this)
        );
        uint256 underlyingTokenBalanceBefore = underlyingToken.balanceOf(
            address(this)
        );

        underlyingToken.safeTransferFrom(msg.sender, address(this), _amount);

        if (
            underlyingToken.allowance(address(this), idleCDOAddress) < _amount
        ) {
            // Avoid issues with some tokens requiring 0
            underlyingToken.safeApprove(address(idleCDOAddress), 0);
            underlyingToken.safeApprove(
                address(idleCDOAddress),
                type(uint256).max
            );
        }

        uint256 qtyMinted = isAATranche
            ? idleCdo.depositAA(_amount)
            : idleCdo.depositBB(_amount);
        trancheToken.safeTransfer(msg.sender, qtyMinted);

        assert(
            trancheTokenBalanceBefore ==
                trancheToken.balanceOf(address(this)) &&
                underlyingTokenBalanceBefore ==
                underlyingToken.balanceOf(address(this))
        );

        emit TokensDeposited(
            msg.sender,
            _token,
            address(trancheToken),
            _amount
        );
    }

    /**
     * @notice base function for withdrawing the underlying with interest
     * Note: no approval required for withdrawal
     * @param _trancheTokenAddress the CDO Tranche token
     * @param _amount of the Tranche token token to burn
     * @param isAATranche set to true to withdraw from an AA Tranche,
     * set to false to withdraw from a BB Tranche 
     */
    function _withdraw(
        address _trancheTokenAddress,
        uint256 _amount,
        bool isAATranche
    ) internal {
        address idleCDOAddress = IIdleCDOTranche(_trancheTokenAddress).minter();
        require(idleCDOAddress != address(0), "IdleRouter: INVALID_TOKEN");

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

        // NOTE: no approval required for withdrawal!
        uint256 amountToReturn = isAATranche
            ? idleCdo.withdrawAA(_amount)
            : idleCdo.withdrawBB(_amount);

        underlyingToken.transfer(msg.sender, amountToReturn);

        assert(
            trancheTokenBalanceBefore ==
                trancheToken.balanceOf(address(this)) &&
                underlyingTokenBalanceBefore ==
                underlyingToken.balanceOf(address(this))
        );

        emit TokensWithdrew(
            msg.sender,
            address(underlyingToken),
            _trancheTokenAddress,
            _amount
        );
    }
}
