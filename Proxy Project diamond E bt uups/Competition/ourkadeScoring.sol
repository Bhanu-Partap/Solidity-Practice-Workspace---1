// SPDX-License-Identifier:MIT
pragma solidity ^0.8.17;

import "../Profile/loyalty.sol";

abstract contract ourkadeScoring is Loyalty{

    function ScoreCompetition(bytes32 _competitionId, uint96 _nodeNumber) public {
		Competition storage foundCompetition = _getCompetition(_competitionId);
		
		// Since we're not checking that the node is online it could technically
		// score a match while "offline", but this should be OK
		bytes32 scoringNode = addressNumberToBytes32(AddressNumber({Address: msg.sender, Number: _nodeNumber}));

		// Competition can't be scored until the time has elapsed
		require(foundCompetition.EndTime < block.timestamp, "PENDING_COMPETITION");

		// If the minimum players has not been met, then it gets cancelled
		if (foundCompetition.Players.length < foundCompetition.MinimumPlayers) {
			_cancelCompetition(_competitionId);
		}

		// The caller needs to be the judge
		bool isJudge = false;

		//console.log("judge 0 is: %s", Strings.toHexString(uint256(foundCompetition.Judges[0])));
		//console.log("judge 1 is: %s", Strings.toHexString(uint256(foundCompetition.Judges[1])));
		//console.log("judge 2 is: %s", Strings.toHexString(uint256(foundCompetition.Judges[2])));
		//console.log("Sender judge is: %s", Strings.toHexString(uint256(addressToBytes32(msg.sender))));

		for (uint i = 0; i < foundCompetition.Judges.length; i++) {
			if (foundCompetition.Judges[i] == scoringNode) {
				// Make the judge wait their turn in the queue to allow the first judge to score
				//console.log("Backup delay is: %s", i * nodeQueueBackupDelay);
				require(block.timestamp > foundCompetition.EndTime + i * nodeQueueBackupDelay, "EARLY_JUDGE");
				isJudge = true;
				break;
			}
		}

		require(isJudge == true, "NOT_JUDGE");

		// Confirm there are disputes
		// This property doesn't indicate if disputes have been resolved
		if (foundCompetition.HasDisputes) {
			// Tried to short-circuit, now we need to iterate
			for (uint i = 0; i < DisputedMatches[_competitionId].length; i++) {
				uint matchIndex = DisputedMatches[_competitionId][i];

				MatchDispute storage matchDispute = MatchDisputes[createMatchDisputeId(_competitionId, matchIndex)];

				if (matchDispute.Status != MatchDisputeStatus.Created) {
					// This dispute has already been resolved, on to the next one
					continue;
				}

				MatchDisputeStatus disputeStatus = MatchDisputeCalculateStatus(_competitionId, matchIndex);

				// Auto-resolve expired ones if we can
				if (disputeStatus == MatchDisputeStatus.Expired) {
					VoteType[] memory ignoreVotes = new VoteType[](0);
					MatchDisputeResolve(_competitionId, matchIndex, ignoreVotes);
				} else if (disputeStatus != MatchDisputeStatus.Innocent && disputeStatus != MatchDisputeStatus.Guilty) {
					// If it hasn't been closed, and we can't automatically resolve it then it's pending for now
					revert("PENDING_DISPUTE");
				}
				// Else - match is already resolved
			}
		}

		if (foundCompetition.PrizeType == PrizeType.WinnerTakeAll) {
			// Get the top 1 winning matches
			uint topMatchIndex = _getSortedScores(_competitionId, 1)[0];
			Match storage topMatch = foundCompetition.Matches[topMatchIndex];

			PlayerProfile storage winner = _getPlayerProfile(addressToBytes32(topMatch.Player), true, false); // If they got disabled but didn't cheat in this match, still award them
			
			winner.Rewards += foundCompetition.PrizePool;

			foundCompetition.Status = CompetitionStatus.Accepted;

		} else {
			revert("COMPETITION_TYPE_NOT_IMPLEMENTED");
		}
		
		PlayerProfile storage judgeProfile = _getPlayerProfile(msg.sender);

		// Use reputation multiplier
		uint judgeReward = _calculateUnsignedPercent(foundCompetition.NodeReward, _playerRepNodeEarning(judgeProfile.Reputation));

		judgeProfile.Rewards += judgeReward;
		emit LogPlayerProfile(msg.sender, msg.sender, ChangeType.Updated, judgeProfile);

		// Things that apply to all users, like loyalty and reputation changes
		for (uint i = 0; i < foundCompetition.Players.length; i++) {

			address currentPlayer = foundCompetition.Players[i];
			// Check if the player's match is disabled (they cheated)
			bytes memory matchCheckId = createMatchCheckId(foundCompetition.CompetitionId, currentPlayer);
			// This checks for the first match because we're not checking the actual duration right now
			// If they cheat then all matches will be disabled, so checking the first one is enough
			Match storage checkMatch = foundCompetition.Matches[CompetitionMatchCheck[matchCheckId][0]];

			if (checkMatch.Status == MatchStatus.Disabled) {
				// They cheated. Actions should already be handled in MatchDisputeResolve
			} else {
				// They did not cheat. Do the needful.

				// Always give 1 minute
				uint16 minutesToAdd = 1;

				// If it' over a minute, round up at 30 seconds and add that many minutes
				if (foundCompetition.MatchDuration > 60) {
					minutesToAdd = uint16(foundCompetition.MatchDuration / 60);
					
					// Round up at 30 seconds
					if (foundCompetition.MatchDuration % 60 >= 30) {
						minutesToAdd += 1;
					}
				}
				_addPlayerGameScore(addressToBytes32(currentPlayer), foundCompetition.GameDefinition, checkMatch.Score);
				_addPlayerLoyalty(currentPlayer, minutesToAdd);
				_addPlayerReputation(currentPlayer, int32(RepAdjustFinishMatch));
				// TODO: Should we add an event here for player profile update?
			}
		}
	}

}