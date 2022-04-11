// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.11;

import "../contracts/IdleRouter.sol";

contract IdleRouterV2 is IdleRouter {
    bool public isUpgraded;

    function setUpgraded(bool _isUpgraded) external {
        isUpgraded = _isUpgraded;
    }
}
