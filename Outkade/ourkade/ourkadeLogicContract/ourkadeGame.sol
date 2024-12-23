// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {ourkadelib} from "../library/ourkadelib.sol";
import "../Types.sol";

contract OurkadeGame {
    // CRUD methods
    // _create - self explanatory
    // _remove - self explanatory
    // _get - internal method that can return (and edit) storage
    // check - checks for existence but does not throw
    // _verify - checks for existence and throws error if false
    // get - external method that returns memory and cannot edit
    // getCount - get count of items
    // getAtIndex - get item by index

    /* #region  GameDefinitions */

    /* #region  GameDefinitions */
    function _createGameDefinition(
        bytes32 key,
        GameDefinition memory newItem
    ) private {
        ourkadelib._createGameDefinition(key, newItem);
    }

    function _removeGameDefinition(bytes32 key) private {
        // This will fail automatically if the key doesn't exist
        ourkadelib._removeGameDefinition(key);
    }

    function checkGameDefinition(bytes32 key) public view returns (bool) {
        return ourkadelib.checkGameDefinition(key);
    }

    function _verifyGameDefinition(bytes32 key) private view {
        ourkadelib._verifyGameDefinition(key);
    }

    function _getGameDefinition(
        bytes32 key
    ) internal view returns (GameDefinition storage) {
        // We have to verify, because array lookup won't fail if it's null

        return ourkadelib._getGameDefinition(key);
    }

    function getGameDefinition(
        bytes32 key
    ) public view returns (GameDefinition memory) {
        return ourkadelib.getGameDefinition(key);
    }

    function getGameDefinitionCount() public view returns (uint256 count) {
        return ourkadelib.getGameDefinitionCount();
    }

    function getGameDefinitionAtIndex(
        uint256 index
    ) public view returns (bytes32 key) {
        return ourkadelib.getGameDefinitionAtIndex(index);
    }
}
