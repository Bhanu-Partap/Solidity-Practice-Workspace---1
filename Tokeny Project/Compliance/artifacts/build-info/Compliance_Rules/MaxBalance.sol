// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../Compliance.sol";


abstract contract MaxBalance is Compliance {

    uint256 public maxBalance;

// mapping of balances per ONCHAINID
    mapping (address => uint256) public IDBalance;

    event MaxBalanceSet(uint256 _maxBalance);

    function setMaxBalance(uint256 _max) external onlyOwner {
        maxBalance = _max;
        emit MaxBalanceSet(_max);
    }

    function complianceCheckOnMaxBalance (address /*_from*/, address _to, uint256 _value) public view returns (bool) {
        if (_value > maxBalance) {
            return false;
        }
        address _id = _getIdentity(_to);
        if ((IDBalance[_id] + _value) > maxBalance) {
            return false;
        }
        return true;
    }

    function _transferActionOnMaxBalance(address _from, address _to, uint256 _value) internal {
        address _idFrom = _getIdentity(_from);
        address _idTo = _getIdentity(_to);
        IDBalance[_idTo] += _value;
        IDBalance[_idFrom] -= _value;
        require (IDBalance[_idTo] <= maxBalance, "post-transfer balance too high");
    }

    function _creationActionOnMaxBalance(address _to, uint256 _value) internal {
        address _idTo = _getIdentity(_to);
        IDBalance[_idTo] += _value;
        require (IDBalance[_idTo] <= maxBalance, "post-minting balance too high");
    }

    function _destructionActionOnMaxBalance(address _from, uint256 _value) internal {
        address _idFrom = _getIdentity(_from);
        IDBalance[_idFrom] -= _value;
    }
}