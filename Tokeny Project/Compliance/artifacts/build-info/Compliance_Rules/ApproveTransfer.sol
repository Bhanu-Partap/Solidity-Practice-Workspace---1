// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../Compliance.sol";

abstract contract ApproveTransfer is  Compliance {

/// Mapping of transfersApproved
    mapping(bytes32 => bool) private _transfersApproved;

//Events
    event TransferApproved(address _from, address _to, uint _amount, address _token);

    event ApprovalRemoved(address _from, address _to, uint _amount, address _token);

//Functions
    function removeApproval(address _from, address _to, uint _amount) external onlyAdmin {
        bytes32 transferId = _calculateTransferID (_from, _to, _amount, address(tokenBound));
        require(_transfersApproved[transferId], "transfer not approved yet");
        _transfersApproved[transferId] = false;
        emit ApprovalRemoved(_from, _to, _amount, address(tokenBound));
    }

    function approveAndTransfer(address _from, address _to, uint _amount) external {
        approveTransfer(_from, _to, _amount);
        tokenBound.transferFrom(_from, _to, _amount);
    }

    function approveTransfer(address _from, address _to, uint _amount) public onlyAdmin {
        bytes32 transferId = _calculateTransferID (_from, _to, _amount, address(tokenBound));
        require(!_transfersApproved[transferId], "transfer already approved");
        _transfersApproved[transferId] = true;
        emit TransferApproved(_from, _to, _amount, address(tokenBound));
    }

    function complianceCheckOnApproveTransfer(address _from, address _to, uint256 _value) public view returns (bool) {
        if (!isTokenAgent(_from)) {
            bytes32 transferId = _calculateTransferID (_from, _to, _value, address(tokenBound));
            if (!_transfersApproved[transferId]){
                return false;
            }
        }
        return true;
    }

    function _transferActionOnApproveTransfer(address _from, address _to, uint256 _value) internal {
        _transferProcessed(_from, _to, _value);
    }

    function _creationActionOnApproveTransfer(address _to, uint256 _value) internal {}

    function _destructionActionOnApproveTransfer(address _from, uint256 _value) internal {}

    function _transferProcessed(address _from, address _to, uint _amount) internal {
        bytes32 transferId = _calculateTransferID (_from, _to, _amount, address(tokenBound));
        if (_transfersApproved[transferId]) {
            _transfersApproved[transferId] = false;
            emit ApprovalRemoved(_from, _to, _amount, address(tokenBound));
        }
    }

    function _calculateTransferID (
        address _from,
        address _to,
        uint _amount,
        address _token
    ) internal pure returns (bytes32){
        bytes32 transferId = keccak256(abi.encode(_from, _to, _amount, _token));
        return transferId;
    }
}