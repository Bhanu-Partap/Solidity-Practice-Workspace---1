// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import "./AbstractProxy.sol";

contract IdentityRegistryProxy is AbstractProxy {
    constructor(
        address implementationAuthority,
        address _trustedIssuersRegistry,
        address _claimTopicsRegistry,
        address _identityStorage
    ) {
        require(
            implementationAuthority != address(0) &&
                _trustedIssuersRegistry != address(0) &&
                _claimTopicsRegistry != address(0) &&
                _identityStorage != address(0),
            "invalid argument - zero address"
        );
        _storeImplementationAuthority(implementationAuthority);
        emit ImplementationAuthoritySet(implementationAuthority);

        address logic = Ifactory(getImplementationAuthority())
            .getIRImplementation();

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = logic.delegatecall(
            abi.encodeWithSignature(
                "init(address,address,address)",
                _trustedIssuersRegistry,
                _claimTopicsRegistry,
                _identityStorage
            )
        );
        require(success, "Initialization failed.");
    }

    // solhint-disable-next-line no-complex-fallback
    fallback() external {
        address logic = Ifactory(getImplementationAuthority())
            .getIRImplementation();

        // solhint-disable-next-line no-inline-assembly
        assembly {
            calldatacopy(0x0, 0x0, calldatasize())
            let success := delegatecall(
                sub(gas(), 10000),
                logic,
                0x0,
                calldatasize(),
                0,
                0
            )
            let retSz := returndatasize()
            returndatacopy(0, 0, retSz)
            switch success
            case 0 {
                revert(0, retSz)
            }
            default {
                return(0, retSz)
            }
        }
    }
}
