// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;
import {ourkadelib} from "../library/ourkadelib.sol";
import "../Types.sol";

contract Newfuc {
    function setRepGuiltyLimit(uint8 _guiltylimit) public {
        ourkadelib.setRepGuiltyLimit(_guiltylimit);
    }

    function readRepGuiltyLimit() public view returns (uint8) {
        return ourkadelib.readRepGuiltyLimit();
    }
}
