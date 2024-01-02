// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// import "../Compliance.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/TokenySolutions/T-REX/blob/main/contracts/token/IToken.sol";


abstract contract SupplyLimit is Ownable {
        
    IToken public tokenBound;


    uint256 public supplyLimit;

    event SupplyLimitSet(uint256 _limit);

    function setSupplyLimit(uint256 _limit) external onlyOwner {
        supplyLimit = _limit;
        emit SupplyLimitSet(_limit);
    }

    function complianceCheckOnSupplyLimit (address /*_from*/, address /*_to*/, uint256 /*_value*/)
    public view returns (bool) {
        return true;
    }

    function _transferActionOnSupplyLimit(address _from, address _to, uint256 _value) internal {}

    function _creationActionOnSupplyLimit(address /*_to*/, uint256 /*_value*/) internal {
        require(tokenBound.totalSupply() <= supplyLimit, "cannot mint more tokens");
    }

    function _destructionActionOnSupplyLimit(address _from, uint256 _value) internal {}
}