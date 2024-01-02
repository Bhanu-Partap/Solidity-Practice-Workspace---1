// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IModule {

// events
    event ComplianceBound(address indexed _compliance);

    event ComplianceUnbound(address indexed _compliance);

// functions
    function bindCompliance(address _compliance) external;

    function unbindCompliance(address _compliance) external;

    function moduleTransferAction(address _from, address _to, uint256 _value) external;

    function moduleMintAction(address _to, uint256 _value) external;

    function moduleBurnAction(address _from, uint256 _value) external;

    function moduleCheck(address _from, address _to, uint256 _value, address _compliance) external view returns (bool);

    function isComplianceBound(address _compliance) external view returns (bool);
}