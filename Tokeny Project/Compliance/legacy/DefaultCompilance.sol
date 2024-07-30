// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./Compliance.sol";

contract DefaultCompliance is Compliance {

    function transferred(address _from, address _to, uint256 _value) external override {
    }

    function created(address _to, uint256 _value) external override {
    }

    function destroyed(address _from, uint256 _value) external override {
    }

    function canTransfer(address /*_from*/, address /*_to*/, uint256 /*_value*/) external view override returns (bool) {
        return true;
    }

     function getcontractaddress() public view returns (address) {
        return address(this);
    }
}