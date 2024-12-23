// SPDX-License-Identifier:MIT
pragma solidity ^0.8.17;

import "../Types.sol";

abstract contract regionCompetition{
    
    //// Competition Storage
    using HitchensUnorderedKeySetLib for HitchensUnorderedKeySetLib.Set;
	HitchensUnorderedKeySetLib.Set internal competitionLookup;
	mapping(bytes32 => Competition) internal competitions;

    // events 
    event LogCompetition(address indexed sender, bytes32 indexed key, ChangeType indexed change, Competition competition);

    /* #region  Competitions */

	// function _createCompetition(bytes32 key, Competition memory newItem) private {
	//  Not implemented due to special logic
	// 	competitionLookup.insert(key);
	// 	competitions[key] = newItem;
	// 	emit LogCompetition(msg.sender, key, newItem);
	// }

    function _removeCompetition(bytes32 key) internal {
		// This will fail automatically if the key doesn't exist
		Competition memory removedItem = competitions[key];
        competitionLookup.remove(key); 
        delete competitions[key];
        emit LogCompetition(msg.sender, key, ChangeType.Removed, removedItem);
    }

    function checkCompetition(bytes32 key) public view returns(bool) {
		return competitionLookup.exists(key);
	}

	function _verifyCompetition(bytes32 key) private view {
		require(checkCompetition(key) == true, "COMPETITION_DOES_NOT_EXIST");
	}

    function _getCompetition(bytes32 key) view internal returns(Competition storage) {
		// We have to verify, because array lookup won't fail if it's null
		_verifyCompetition(key);
        Competition storage item = competitions[key];
        return(item);
    }

    function getCompetition(bytes32 key) public view returns(Competition memory) {
		return(_getCompetition(key));
    }

    function getCompetitionCount() public view returns(uint count) {
        return competitionLookup.count();
    }

    function getCompetitionAtIndex(uint index) public view returns(bytes32 key) {
        return competitionLookup.keyAtIndex(index);
    }

    /* #endregion */

}