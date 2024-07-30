// SPDX-License-Identifier:MIT
pragma solidity ^0.8.17;

import "../Competition/disputesPublic.sol";

abstract contract Loyalty is disputePublic {

    // Reputation variables
    uint nodeQueueBackupDelay = 10; // Time that each backup has to wait. Nth backup has to wait N * BackupDelay
    uint32 internal RepAdjustFinishMatch = 100; // Reputation for completing a match undisputed

    mapping (address => uint16) private DailyMinutesPlayed; // Used to track daily matches and calculate loyalty
    // mapping (bytes32 => uint[]) private DisputedMatches; // Key: Competition ID. Value: The indices of matches disputed
    // mapping (bytes => MatchDispute) private MatchDisputes; // Key: Competition ID + Match Index. Value: Dispute details
    // mapping (bytes => uint8[]) private CompetitionMatchCheck; // Key: Competition ID + Player Address. Value: Rounds in match

    function _calculateLoyalty(address _player, int32 _reputation, uint16 _addMinutes) internal view returns(uint64) {
		uint16 currentMinutes = DailyMinutesPlayed[_player];

		require(_addMinutes > 0 && _addMinutes < 24 * 60, "INVALID_PLAYTIME"); // At least one minute, and less minutes than in a day

		//sssss Only loop up to length of loyalty calculation
		uint16 loopMinutes = _addMinutes;

		if (_addMinutes > LoyaltyLookup.length) {
			loopMinutes = uint16(LoyaltyLookup.length);
		}

		//console.log("_addMinutes: %s", uint(_addMinutes));
		//console.log("loopMinutes: %s", uint(loopMinutes));
		//console.log("LoyaltyLookup.length: %s", uint(LoyaltyLookup.length));

		uint64 loyaltyToAdd = 0;

		for (uint i = currentMinutes + 1; i <= currentMinutes + loopMinutes; i++) {
			loyaltyToAdd += LoyaltyLookup[i - 1]; // loyalty is 0-indexed, played minutes is 1-indexed
			//console.log("Accumulated loyalty: %s", uint(loyaltyToAdd));
		}

		// Now multiply the loyalty by the reputation bonus, which could bring it to zero
		loyaltyToAdd = uint64(_calculateUnsignedPercent(loyaltyToAdd, _playerRepLoyaltyMultiplier(_reputation)));
		//console.log("Percentage applied loyalty: %s", uint(loyaltyToAdd));

		return loyaltyToAdd;
	}

    function _addPlayerLoyalty(address _player, uint16 _addMinutes) internal {
		PlayerProfile storage profile = _getPlayerProfile(_player);
		
		//console.log("Loyalty before: %s", uint(profile.Loyalty)); 
		//console.log("Adding minutes: %s", uint(_addMinutes));
		//console.log("Reputation: %s", uint(int256(profile.Reputation)));
		profile.Loyalty += _calculateLoyalty(_player, profile.Reputation, _addMinutes);
		//console.log("Loyalty after: %s", uint(profile.Loyalty)); 
		DailyMinutesPlayed[_player] += _addMinutes;
	}

    function _addPlayerReputation(address _player, int32 _add) internal {
		PlayerProfile storage profile = _getPlayerProfile(_player);
		profile.Reputation += _add;
	}

}