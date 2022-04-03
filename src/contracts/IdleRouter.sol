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

    function initialize(address _idleRegistry) external initializer {
        OwnableUpgradeable.__Ownable_init();
        setIdleRegistry(_idleRegistry);
    }

    function setIdleRegistry(address _idleRegistry) public onlyOwner {
        require(
            _idleRegistry != address(0) && _idleRegistry != idleRegistry,
            "IdleRouter: INVALID_ADDRESS"
        );
        idleRegistry = _idleRegistry;
        emit IdleRegistryUpdated(_idleRegistry);
    }

    function depositAA(address _token, uint256 _amount) external {
        _deposit(_token, _amount, true);
    }

    function depositBB(address _token, uint256 _amount) external {
        _deposit(_token, _amount, false);
    }

    function withdrawAA(address _trancheTokenAA, uint256 _amount) external {
        _withdraw(_trancheTokenAA, _amount, true);
    }

    function withdrawBB(address _trancheTokenBB, uint256 _amount) external {
        _withdraw(_trancheTokenBB, _amount, false);
    }

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
