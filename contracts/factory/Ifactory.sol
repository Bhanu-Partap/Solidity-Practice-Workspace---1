// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

interface Ifactory {
    function getTokenImplementation() external view returns (address);

    function getCTRImplementation() external view returns (address);

    function getIRImplementation() external view returns (address);

    function getIRSImplementation() external view returns (address);

    function getTIRImplementation() external view returns (address);

    function getMCImplementation() external view returns (address);
}
