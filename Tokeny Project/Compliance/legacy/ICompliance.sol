// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ICompliance {
   
    event TokenAgentAdded(address _agentAddress);

    event TokenAgentRemoved(address _agentAddress);

    event TokenBound(address _token);

    event TokenUnbound(address _token);

    function addTokenAgent(address _agentAddress) external;

    function removeTokenAgent(address _agentAddress) external;

    function bindToken(address _token) external;

    function unbindToken(address _token) external;

    function transferred(
        address _from,
        address _to,
        uint256 _amount
    ) external;

    function created(address _to, uint256 _amount) external;

    function destroyed(address _from, uint256 _amount) external;

    function isTokenAgent(address _agentAddress) external view returns (bool);

    function isTokenBound(address _token) external view returns (bool);

    function canTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) external view returns (bool);
}