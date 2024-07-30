// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../IModularCompliance.sol";
import "./AbstractModule.sol";

contract ConditionalTransferModule is AbstractModule {
    // Mapping between transfer details and their approval status (amount of transfers approved) per compliance
    mapping(address => mapping(bytes32 => uint256)) private _transfersApproved;

    event TransferApproved(
        address _from,
        address _to,
        uint256 _amount,
        address _token
    );

    event ApprovalRemoved(
        address _from,
        address _to,
        uint256 _amount,
        address _token
    );

    function batchApproveTransfers(
        address[] calldata _from,
        address[] calldata _to,
        uint256[] calldata _amount
    ) external onlyComplianceCall {
        for (uint256 i = 0; i < _from.length; i++) {
            approveTransfer(_from[i], _to[i], _amount[i]);
        }
    }

    function batchUnApproveTransfers(
        address[] calldata _from,
        address[] calldata _to,
        uint256[] calldata _amount
    ) external onlyComplianceCall {
        for (uint256 i = 0; i < _from.length; i++) {
            unApproveTransfer(_from[i], _to[i], _amount[i]);
        }
    }

    function moduleTransferAction(
        address _from,
        address _to,
        uint256 _value
    ) external override onlyComplianceCall {
        bytes32 transferHash = calculateTransferHash(
            _from,
            _to,
            _value,
            IModularCompliance(msg.sender).getTokenBound()
        );
        if (_transfersApproved[msg.sender][transferHash] > 0) {
            _transfersApproved[msg.sender][transferHash]--;
            emit ApprovalRemoved(
                _from,
                _to,
                _value,
                IModularCompliance(msg.sender).getTokenBound()
            );
        }
    }

    function moduleMintAction(address _to, uint256 _value)
        external
        override
        onlyComplianceCall
    {}

    function moduleBurnAction(address _from, uint256 _value)
        external
        override
        onlyComplianceCall
    {}

    function moduleCheck(
        address _from,
        address _to,
        uint256 _value,
        address _compliance
    ) external view override returns (bool) {
        bytes32 transferHash = calculateTransferHash(
            _from,
            _to,
            _value,
            IModularCompliance(_compliance).getTokenBound()
        );
        return isTransferApproved(_compliance, transferHash);
    }

    function approveTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) public onlyComplianceCall {
        bytes32 transferHash = calculateTransferHash(
            _from,
            _to,
            _amount,
            IModularCompliance(msg.sender).getTokenBound()
        );
        _transfersApproved[msg.sender][transferHash]++;
        emit TransferApproved(
            _from,
            _to,
            _amount,
            IModularCompliance(msg.sender).getTokenBound()
        );
    }

    function unApproveTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) public onlyComplianceCall {
        bytes32 transferHash = calculateTransferHash(
            _from,
            _to,
            _amount,
            IModularCompliance(msg.sender).getTokenBound()
        );
        require(
            _transfersApproved[msg.sender][transferHash] > 0,
            "not approved"
        );
        _transfersApproved[msg.sender][transferHash]--;
        emit ApprovalRemoved(
            _from,
            _to,
            _amount,
            IModularCompliance(msg.sender).getTokenBound()
        );
    }

    function isTransferApproved(address _compliance, bytes32 _transferHash)
        public
        view
        returns (bool)
    {
        if (((_transfersApproved[_compliance])[_transferHash]) > 0) {
            return true;
        }
        return false;
    }

    function getTransferApprovals(address _compliance, bytes32 _transferHash)
        public
        view
        returns (uint256)
    {
        return (_transfersApproved[_compliance])[_transferHash];
    }

    function calculateTransferHash(
        address _from,
        address _to,
        uint256 _amount,
        address _token
    ) public pure returns (bytes32) {
        bytes32 transferHash = keccak256(
            abi.encode(_from, _to, _amount, _token)
        );
        return transferHash;
    }
}
