// SPDX-License-Identifier:MIT
pragma solidity ^0.8.17;

import "./players.sol";

abstract contract Reputation is regionProfile{

    uint8 private RepToZeroDays = 33; // Number of days until rep is automatically set to 0.
    

    // Temporal data
    mapping(address => uint) playerLastCalcLookup;
    mapping(address => uint) playerDailyVotes;
	mapping(address => uint) playerDailyFlags;


    //// Reputation (Clout) Functions

	// We don't need a function for "can join competition" because
	// competitions set their own join criteria, including Reputation.

    // Accepts a reputation and returns a node earning percentage
	function _playerRepNodeEarning(int32 _reputation) pure internal returns(uint8) {
		if (_reputation > 32000 ) {
			return 100;
		} else if (_reputation > 20000) {
			return 75;
		} else if (_reputation > 4000) {
			return 50;
		} else {
			return 0;
		}
	}

    // Accepts a reputation and returns a loyalty earning multiplier
	function _playerRepLoyaltyMultiplier(int32 _reputation) pure internal returns(uint8) {
		if (_reputation > 32000 ) {
			return 125;
		} else if (_reputation > 20000) {
			return 110;
		} else if (_reputation >= 0) {
			return 100;
		} else {
			return 0;
		}
	}

    // The Flag, Vote, and Update functions all depend on the day
	// They will compare the player's current allowable flags
	// ,which is based on reputation, and the number of times they
	// have flagged already. If it's not allow, this will revert
	// This function assumes _playerRepUpdate has been called already
	// which will ensure the daily reset happens
	function _playerRepFlag(address _player, int32 _reputation) internal {
		uint allowedFlags = 0;

		if (_reputation > 32000) {
			allowedFlags = 4;
		} else if (_reputation > 20000) {
			allowedFlags = 3;
		} else if (_reputation > 4000) {
			allowedFlags = 2;
		}

		require(playerDailyFlags[_player] < allowedFlags, "INSUFFICIENT_FLAGS");

		playerDailyFlags[_player]++;
	}

	function _playerRepVote(address _player, int32 _reputation) internal {
		uint allowedVotes = 0;

		if (_reputation > 32000) {
			allowedVotes = 3;
		} else if (_reputation > 20000) {
			allowedVotes = 2;
		} else if (_reputation > 4000) {
			allowedVotes = 1;
		}

		require(playerDailyVotes[_player] < allowedVotes, "INSUFFICIENT_VOTES");

		playerDailyVotes[_player]++;
	}


	// This function will be called every time and will
	// only perform updates when necessary.
	// This will allow the profile to be updated if it's
	// disabled, which means the caller needs to check that
	function _playerRepUpdate(PlayerProfile storage _profile) internal {
		address _playerAddress = bytes32ToAddress(_profile.PlayerProfileId);
		uint _latestDay = _getDay();

		// First check if the rep has already been checked
		if (playerLastCalcLookup[_playerAddress] == _latestDay) {
			// Rep has already been calculated
			return;
		}

		// TODO: Set player's last activity on necessary actions

		// Check if rep needs to be updated
		uint lastActive = playerLastActivity[_playerAddress];
		uint16 inactiveDays = 0;
		if (lastActive < _latestDay - seconds_in_day) { // Not active since before yesterday?
			inactiveDays = uint16((_latestDay - lastActive) / seconds_in_day);

			if (inactiveDays > RepToZeroDays) {
				_profile.Reputation = 0;
			} else {
				_profile.Reputation += _calculateIdleReputationLoss(_profile.Reputation, inactiveDays);
			}
			
		}

		// Do other daily resets
		playerDailyVotes[_playerAddress] = 0;
		playerDailyFlags[_playerAddress] = 0;

		playerLastCalcLookup[_playerAddress] = _latestDay;
	}

    function _calculateIdleReputationLoss(int32 _startingRep, uint16 _days) internal pure returns(int32) {
		require(_days > 0, "INVALID_DURATION");

		// Get the sign, then do all work in positive.
		int8 signMultiplier = 1;

		if (_startingRep < 0 ) { signMultiplier = -1;}

		// If it's negative, turn it positive, widen it, then make it unsigned
		uint endingRep = uint(int(_startingRep * signMultiplier));

		for (uint16 i = 0; i < _days; i++) {
			endingRep = sqrt(endingRep)/3;
		}

		return int32(int(endingRep) * signMultiplier);
	}

	
}