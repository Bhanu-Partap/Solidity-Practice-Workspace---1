/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

library accesslib {
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    error AccessControlBadConfirmation();

    event RoleAdminChanged(
        bytes32 indexed role,
        bytes32 indexed previousAdminRole,
        bytes32 indexed newAdminRole
    );

    event RoleGranted(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );

    event RoleRevoked(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );

    struct RoleData {
        mapping(address => bool) hasRole;
        bytes32 adminRole;
    }
    struct roles {
        mapping(bytes32 => RoleData) _roles;
    }

    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;

    modifier onlyRole(roles storage S, bytes32 role) {
        _checkRole(S, role);
        _;
    }

    //Returns `true` if `account` has been granted `role`.
    function hasRole(
        roles storage S,
        bytes32 role,
        address account
    ) internal view returns (bool) {
        return S._roles[role].hasRole[account];
    }

    /*   Reverts with an {AccessControlUnauthorizedAccount} error if `_msgSender()`
     * is missing `role`. Overriding this function changes the behavior of the {onlyRole} modifier.*/
    function _checkRole(roles storage S, bytes32 role) internal view {
        _checkRole(S, role, msg.sender);
    }

    function _checkRole(
        roles storage S,
        bytes32 role,
        address account
    ) internal view {
        require(hasRole(S, role, account),"not authorised role");
        // if (!hasRole(S, role, account)) {
        //     revert AccessControlUnauthorizedAccount({account:account, neededRole:role});
        // }
    }

    //Returns the admin role that controls `role`

    function getRoleAdmin(roles storage S, bytes32 role)
        internal
        view
        returns (bytes32)
    {
        return S._roles[role].adminRole;
    }

    // Grants `role` to `account`.
    function grantRole(
        roles storage S,
        bytes32 role,
        address account
    ) internal onlyRole(S, getRoleAdmin(S, role)) {
        _grantRole(S, role, account);
    }

    // Revokes `role` from `account`
    function revokeRole(
        roles storage S,
        bytes32 role,
        address account
    ) internal onlyRole(S, getRoleAdmin(S, role)) {
        _revokeRole(S, role, account);
    }

    // Revokes `role` from the calling account.
    function renounceRole(
        roles storage S,
        bytes32 role,
        address callerConfirmation
    ) internal {
        if (callerConfirmation != msg.sender) {
            revert AccessControlBadConfirmation();
        }

        _revokeRole(S, role, callerConfirmation);
    }

    function _setRoleAdmin(
        roles storage S,
        bytes32 role,
        bytes32 adminRole
    ) internal {
        bytes32 previousAdminRole = getRoleAdmin(S, role);
        S._roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    function _grantRole(
        roles storage S,
        bytes32 role,
        address account
    ) internal returns (bool) {
        if (!hasRole(S, role, account)) {
            S._roles[role].hasRole[account] = true;
            emit RoleGranted(role, account, msg.sender);
            return true;
        } else {
            return false;
        }
    }

    function _revokeRole(
        roles storage S,
        bytes32 role,
        address account
    ) internal returns (bool) {
        if (hasRole(S, role, account)) {
            S._roles[role].hasRole[account] = false;
            emit RoleRevoked(role, account, msg.sender);
            return true;
        } else {
            return false;
        }
    }
}
