// SPDX-License-Identifier:MIT
pragma solidity ^0.8.17;

import "../Types.sol";

abstract contract crudMethods {

    //// Game Storage
    HitchensUnorderedKeySetLib.Set internal gameDefinitionLookup;
    using HitchensUnorderedKeySetLib for HitchensUnorderedKeySetLib.Set;
	mapping(bytes32 => GameDefinition) internal gameDefinitions;

    // events
    event LogGame(address indexed sender, bytes32 indexed key, ChangeType indexed change, GameDefinition game);

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
	function _createGameDefinition(bytes32 key, GameDefinition memory newItem) internal {
		gameDefinitionLookup.insert(key);
		gameDefinitions[key] = newItem;
		emit LogGame(msg.sender, key, ChangeType.Created, newItem);
	}

    function _removeGameDefinition(bytes32 key) internal {
		// This will fail automatically if the key doesn't exist
        gameDefinitionLookup.remove(key); 
		GameDefinition memory removedItem = gameDefinitions[key];
        delete gameDefinitions[key];
        emit LogGame(msg.sender, key, ChangeType.Removed, removedItem);
    }

    function checkGameDefinition(bytes32 key) public view returns(bool) {
		return gameDefinitionLookup.exists(key);
	}

	function _verifyGameDefinition(bytes32 key) internal view {
		require(checkGameDefinition(key) == true, "INVALID_GAME");
	}	    

    function _getGameDefinition(bytes32 key) view internal returns(GameDefinition storage) {
		// We have to verify, because array lookup won't fail if it's null
		_verifyGameDefinition(key);
        GameDefinition storage item = gameDefinitions[key];
        return(item);
    }


    function getGameDefinition(bytes32 key) public view returns(GameDefinition memory) {
		return(_getGameDefinition(key));
    }

    function getGameDefinitionCount() public view returns(uint count) {
        return gameDefinitionLookup.count();
    }

    function getGameDefinitionAtIndex(uint index) public view returns(bytes32 key) {
        return gameDefinitionLookup.keyAtIndex(index);
    }
	/* #endregion */

    
}