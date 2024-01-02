// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IModularCompliance {

// events

    event ModuleInteraction(address indexed target, bytes4 selector);

    event TokenBound(address _token);

    event TokenUnbound(address _token);

    event ModuleAdded(address indexed _module);

    event ModuleRemoved(address indexed _module);

// functions

    function bindToken(address _token) external;

    function unbindToken(address _token) external;

    function addModule(address _module) external;

    function removeModule(address _module) external;

    function callModuleFunction(bytes calldata callData, address _module) external;

    function transferred(
        address _from,
        address _to,
        uint256 _amount
    ) external;

    function created(address _to, uint256 _amount) external;

    function destroyed(address _from, uint256 _amount) external;

    function canTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) external view returns (bool);

    function getModules() external view returns (address[] memory);


    function getTokenBound() external view returns (address);

    function isModuleBound(address _module) external view returns (bool);
}