// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract gasLeftContract{

    uint256 public c=1;

    function _calculateGas()external returns (uint256 gasUsed){
        uint256 startGas = gasleft();
        c++;
        gasUsed = startGas - gasleft();
    }
    //5093 gas Used

    function _optmized() external returns(uint256 gasUsed){
        uint256 startGas = gasleft();
        ++c;
        gasUsed = startGas-gasleft();
    }
    // 5088 gas used

}