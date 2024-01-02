// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./IModule.sol";

abstract contract AbstractModule is IModule {

// compliance contract binding status
    mapping(address => bool) private _complianceBound;

    modifier onlyBoundCompliance(address _compliance) {
        require(_complianceBound[_compliance], "compliance not bound");
        _;
    }

    modifier onlyComplianceCall() {
        require(_complianceBound[msg.sender], "only bound compliance can call");
        _;
    }

    function bindCompliance(address _compliance) external override {
        require(_compliance != address(0), "invalid argument - zero address");
        require(!_complianceBound[_compliance], "compliance already bound");
        require(msg.sender == _compliance, "only compliance contract can call");
        _complianceBound[_compliance] = true;
        emit ComplianceBound(_compliance);
    }

    function unbindCompliance(address _compliance) external onlyComplianceCall override {
        require(_compliance != address(0), "invalid argument - zero address");
        require(msg.sender == _compliance, "only compliance contract can call");
        _complianceBound[_compliance] = false;
        emit ComplianceUnbound(_compliance);
    }

    function isComplianceBound(address _compliance) external view override returns (bool) {
        return _complianceBound[_compliance];
    }

}