// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

contract MCStorage {
    /// token linked to the compliance contract
    address internal _tokenBound;

    /// Array of modules bound to the compliance
    address[] internal _modules;

    /// Mapping of module binding status
    mapping(address => bool) internal _moduleBound;
    
    uint256[49] private __gap;
}