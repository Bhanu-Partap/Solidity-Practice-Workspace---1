// SPDX-License-Identifier:MIT
pragma solidity ^0.8.17;

import "./disputes.sol";

abstract contract disputePublic is Disputes {

    function MatchDisputeResolve(bytes32 _competitionId, uint _matchIndex, VoteType[] memory _revealedVotes) public {
		bytes32 competitionId = _competitionId;
		bytes memory matchDisputeId = createMatchDisputeId(competitionId, _matchIndex);
		MatchDispute storage matchDispute = MatchDisputes[matchDisputeId];

		MatchDisputeStatus disputeStatus = MatchDisputeCalculateStatus(competitionId, _matchIndex);

		// First check if it is already resolved or can be resolved.
		if (matchDispute.Status != MatchDisputeStatus.Created) {
			revert("INACTIVE_DISPUTE");
		} else if (disputeStatus == MatchDisputeStatus.Pending) {
			revert("PENDING_DISPUTE");
		}

		Competition storage competition = _getCompetition(competitionId);

		// Now Check if the person can even resolve it.

		// A match can be marked as expired either because of time or not enough votes
		if (disputeStatus == MatchDisputeStatus.Expired) {
			// Anyone can resolve an expired dispute because it resets everything
			matchDispute.Status = MatchDisputeStatus.Expired;
		} else if (disputeStatus == MatchDisputeStatus.EarlyResolve || disputeStatus == MatchDisputeStatus.VotingClosed) {
			bool isArbitrator = false;

			for (uint i = 0; i < matchDispute.Arbitrators.length; i++) {
				if (matchDispute.Arbitrators[i] == msg.sender) {
					// For arbitration, we don't pay attention to the priority for taking action
					isArbitrator = true;
					break;
				}
			}

			if (!isArbitrator) {
				// This means it's ready to close, but not quite expired, and the user is not an operator
				revert("PENDING_DISPUTE");
			} else if (isArbitrator) {
				// Ready to close, and we know we have enough votes
				uint totalVotes = matchDispute.Votes.length;

				// Update the votes
				uint innocentVotes = 0;
				uint guiltyVotes = 0;

				if (_revealedVotes.length != totalVotes) {
					revert("INVALID_REVEAL");
				}

				// Iterate through the votes, revealing them and counting the total
				for (uint i = 0; i < _revealedVotes.length; i++) {
					VoteType _currentVoteType = _revealedVotes[i];

					MatchDisputeVote storage _currentVote = matchDispute.Votes[i];
					_currentVote.Vote = _currentVoteType;

					if (_currentVoteType == VoteType.Hidden) {
						revert("INVALID_REVEAL");
					} else if (_currentVoteType == VoteType.Guilty) {
						guiltyVotes += 1;
					} else if (_currentVoteType == VoteType.Innocent) {
						innocentVotes += 1;
					}
					// Ignore Invalid, we'll handle it later with the rest of the reputation changes
				}

				// Keep in mind that it is possible for totalVotes != guiltyVotes + innocentVotes because of invalid votes.

				PlayerProfile storage accused = _getPlayerProfile(addressToBytes32(matchDispute.Accused), true, false); // Track the cheating, even if they are disabled
				PlayerProfile storage accuser = _getPlayerProfile(addressToBytes32(matchDispute.Accuser), true, false); // Resolve dispute even if accuser is disabled
				
				assert(totalVotes >= DisputeVotesRequired);

				// Decide the ruling
				VoteType disputeResult = guiltyVotes > innocentVotes ? VoteType.Guilty : VoteType.Innocent;

				if (disputeResult == VoteType.Guilty) {
					/// Handle Accused
					// Calculate penalty
					uint16 guiltyPenalty = _calculatePenalty(guiltyVotes, innocentVotes, accused.GuiltyCount);
					
					accused.Reputation -= int16(guiltyPenalty);
					accused.GuiltyCount += 1;
					accused.LastGuiltyTimestamp = block.timestamp;

					if (accused.Status != PlayerProfileStatus.Disabled && (accused.Reputation <= RepInstantBan || accused.GuiltyCount >= RepGuiltyLimit)) {
						_removePlayerProfile(accused.PlayerProfileId);
					}

					// Disable all competition matches from the cheater
					address player = bytes32ToAddress(accused.PlayerProfileId);
					// bytes32 competitionId = _competitionId;
					bytes memory _createMatchCheckId = createMatchCheckId(competitionId, player);
                    uint8[] storage disableIndices = CompetitionMatchCheck[_createMatchCheckId];
					

					for (uint i = 0; i < disableIndices.length; i++) {
						competition.Matches[i].Status = MatchStatus.Disabled;
					}

					/// Handle Accuser
					accuser.Reputation += int16(RepAdjustRightAccuse);

					/// Resolve Dispute
					matchDispute.Status = MatchDisputeStatus.Guilty;
				} else {
					// Not Guilty

					/// Handle Accused - Not Applicable

					/// Handle Accuser
					accuser.Reputation -= int16(RepAdjustWrongAccuse);

					/// Resolve Dispute
					matchDispute.Status = MatchDisputeStatus.Innocent;
				}

				// Handle voters in one loop
				for (uint i = 0; i < matchDispute.Votes.length; i++) {
					MatchDisputeVote storage _currentVote = matchDispute.Votes[i];

					PlayerProfile storage _currentVoter = _getPlayerProfile(_currentVote.Voter);

					if (_currentVote.Vote == VoteType.Invalid) {
						// Invalid vote
						_currentVoter.Reputation = RepInstantBan;
						_removePlayerProfile(_currentVote.Voter);
					} else if (_currentVote.Vote == disputeResult) {
						// Correct vote
						_currentVoter.Reputation -= int32(RepAdjustRightVote);
					} else {
						// Incorrect vote
						_currentVoter.Reputation -= int32(RepAdjustWrongVote);
					}
					
				}
			}
		}

		emit LogActionCompleted(msg.sender, AssignedAction.MatchDispute, matchDisputeId);
	}

	function MatchDisputeSubmitVote(bytes32 _competitionId, uint _matchIndex, bytes32 _signature, bytes[] calldata _reveals) public onlyRole(ROLE_OPERATOR) {
		MatchDispute storage matchDispute = MatchDisputes[createMatchDisputeId(_competitionId, _matchIndex)];

		require(matchDispute.MatchIndex != 0, "INVALID_DISPUTE");
		require(matchDispute.Status == MatchDisputeStatus.Created, "DISPUTE_CLOSED");
		require(matchDispute.Voters[msg.sender] == false, "DUPLICATE_VOTE");
		// Don't allow accuser or accused to vote
		require(matchDispute.Accuser != msg.sender, "INVALID_VOTE");
		require(matchDispute.Accused != msg.sender, "INVALID_VOTE");
		// Not checking arbitrators because it's a small risk, and a lot of gas to loop through to check.

		// Get the profile of the accuser and use up a vote (or revert if they can't vote)
		PlayerProfile storage accuserProfile = _getPlayerProfile(msg.sender);
		_playerRepVote(msg.sender, accuserProfile.Reputation);

		MatchDisputeStatus disputeStatus = MatchDisputeCalculateStatus(_competitionId, _matchIndex);

		if (disputeStatus == MatchDisputeStatus.Expired) {
			// If it's expired then we can force it to close (and ignore this vote because it's late)
			// Resolve the dispute and exlcude this vote, it's late
			VoteType[] memory ignoreVotes = new VoteType[](0);
			MatchDisputeResolve(_competitionId, _matchIndex, ignoreVotes);
		} else if (disputeStatus == MatchDisputeStatus.Pending || disputeStatus == MatchDisputeStatus.EarlyResolve) {
			// Create the vote struct and add it to the list
			matchDispute.Votes.push(MatchDisputeVote(addressToBytes32(msg.sender), _signature, _reveals, VoteType.Hidden));
			matchDispute.Voters[msg.sender] = true;
		} else if (disputeStatus == MatchDisputeStatus.VotingClosed) {
			revert("VOTING_CLOSED");
		}
	}

 
}