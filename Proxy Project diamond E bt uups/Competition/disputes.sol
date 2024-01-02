// SPDX-License-Identifier:MIT
pragma solidity ^0.8.17;

import "./ourkadeCompetition.sol";
import "../Profile/reputation.sol";

abstract contract Disputes is ourkadeCompetition, Reputation {
    // Reputation variables
    uint private DisputeWindow = 3 * 60 * 60; // How long (in seconds) after a match is submitted that it can be disputed. Default: 3 hours
    uint private DisputeExpiry = 1 * 24 * 60 * 60; // How long (in seconds) after dispute closure until it's expired. Default is: 1 days
    uint8 internal RepGuiltyLimit = 3; // This many guilty verdits instantly bans the player
    uint32 internal RepAdjustRightVote = 400; // Reputation gain for voting correctly
    uint32 internal RepAdjustWrongVote = 0; // Reputation loss for voting incorrectly

    // Event
    event LogActionAssigned(
        address[] indexed assigned,
        AssignedAction action,
        bytes indexed key
    );
    event LogActionCompleted(
        address indexed assigned,
        AssignedAction action,
        bytes indexed key
    );

    /// Dispute Functions
    // Match Dispute Functions
    function MatchDisputeCreate(
        bytes32 _competitionId,
        uint _matchIndex
    ) public {
        Competition storage competition = _getCompetition(_competitionId);

        Match storage disputedMatch = competition.Matches[_matchIndex];

        require(disputedMatch.Status == MatchStatus.Pending, "INVALID_MATCH");
        require(disputedMatch.Player != msg.sender, "INVALID_ACCUSE"); // They can't accuse themselves
        require(
            block.timestamp < disputedMatch.EndTime + DisputeWindow,
            "INVALID_ACCUSE"
        ); // Can't accuse after the window

        // If not an operator, they must have played in the competition to accuse
        if (!hasRole(ROLE_OPERATOR, msg.sender)) {
            uint8[] memory matchesPlayed = CompetitionMatchCheck[
                createMatchCheckId(_competitionId, msg.sender)
            ];
            require(matchesPlayed.length > 0, "INVALID_ACCUSE");
        }

        bytes memory matchDisputeId = createMatchDisputeId(
            _competitionId,
            _matchIndex
        );
        MatchDispute storage matchDispute = MatchDisputes[matchDisputeId];
        require(matchDispute.MatchIndex == 0, "DUPLICATE_DISPUTE");

        competition.HasDisputes = true;

        // Get the profile of the accuser and use up a flag (or revert if they can't accuse)
        PlayerProfile storage accuserProfile = _getPlayerProfile(msg.sender);
        _playerRepFlag(msg.sender, accuserProfile.Reputation);

        // Register dispute
        matchDispute.MatchIndex = _matchIndex;
        matchDispute.Accused = disputedMatch.Player;
        matchDispute.Accuser = msg.sender;
        matchDispute.Status = MatchDisputeStatus.Created;
        matchDispute.Arbitrators = _getMatchDisputeArbitrators(
            msg.sender,
            disputedMatch.Player
        );

        // Add the lookup
        DisputedMatches[_competitionId].push(_matchIndex);

        // TODO: We may need to emit more events for match submission and voting?
        emit LogCompetition(
            msg.sender,
            _competitionId,
            ChangeType.Updated,
            competition
        );
        emit LogActionAssigned(
            matchDispute.Arbitrators,
            AssignedAction.MatchDispute,
            matchDisputeId
        );
    }

    function MatchDisputeCalculateStatus(
        bytes32 _competitionId,
        uint _matchIndex
    ) public view returns (MatchDisputeStatus) {
        Competition storage competition = _getCompetition(_competitionId);
        MatchDispute storage matchDispute = MatchDisputes[
            createMatchDisputeId(_competitionId, _matchIndex)
        ];

        if (matchDispute.Status != MatchDisputeStatus.Created) {
            // If it's not still in Created status then it has resolved
            // so return the status which will be Guilty, Innocent, or Expired
            return matchDispute.Status;
        } else if (
            block.timestamp >=
            competition.EndTime + DisputeDuration + DisputeExpiry
        ) {
            return MatchDisputeStatus.Expired;
        } else if (block.timestamp >= competition.EndTime + DisputeDuration) {
            if (matchDispute.Votes.length >= DisputeVotesRequired) {
                return MatchDisputeStatus.VotingClosed;
            } else {
                return MatchDisputeStatus.Expired; // Not enough votes, so it can be expired early
            }
        } else {
            // Not after the expiry or dispute ending, and disputes are only created after matches
            // This means we are in a time between match ending, and dispute vote closure
            if (matchDispute.Votes.length >= DisputeVotesRequired) {
                return MatchDisputeStatus.EarlyResolve;
            } else {
                return MatchDisputeStatus.Pending;
            }
        }
    }

    // Upon dispute creation, determine the dispute admin
    // Admin cannot be the accuser, accused, or vote on the dispute
    // Voters sign a message with the Admin's public key which includes: Competition, Address, Vote, + other hash?
    // When dispute is resolved, admin decrypts votes and tallys them
    // Voter can dispute decrypted value?
    //		Or by forcing admin to reveal secret (then we should use a different encrypting key which can be rerolled)

    function _calculatePenalty(
        uint _innocentVotes,
        uint _guiltyVotes,
        uint _guiltyCount
    ) internal view returns (uint16) {
        uint8 guiltyVotePercent = uint8(
            (_guiltyVotes / (_guiltyVotes + _innocentVotes)) * 100
        );
        uint16 guiltyPenalty = 0;

        if (
            _innocentVotes > DisputeVotesRequired &&
            _guiltyVotes > DisputeVotesRequired
        ) {
            // Both over 50 votes
            if (guiltyVotePercent >= 90) {
                guiltyPenalty = [3800, 7500, 20100][_guiltyCount];
            } else if (guiltyVotePercent >= 50) {
                guiltyPenalty = [1300, 2500, 20100][_guiltyCount];
            } else if (guiltyVotePercent > 0) {
                guiltyPenalty = [400, 700, 20100][_guiltyCount];
            } else {
                revert("DISPUTE_ERROR");
            }
        } else {
            // Only one over 50 votes
            if (guiltyVotePercent >= 90) {
                guiltyPenalty = [5000, 10000, 20100][_guiltyCount];
            } else if (guiltyVotePercent >= 50) {
                guiltyPenalty = [2500, 5000, 20100][_guiltyCount];
            } else if (guiltyVotePercent > 0) {
                guiltyPenalty = [400, 700, 20100][_guiltyCount];
            } else {
                revert("DISPUTE_ERROR");
            }
        }

        return guiltyPenalty;
    }

    // TODO: This has a problem if the same player has too many nodes stacked together
    // it could cause the loop to iterate too many times and run out of gas
    // looking for enough arbitrators. We need to determine a way to avoid failure
    // One possible way is that if we can't get enough arbitrators because the accuser
    // or the accused has too many nodes, then we take a default action.
    // Another alternative is a separate queue of just node operator profiles
    // Another alternative is picking a "random" one until we find enough
    function _getMatchDisputeArbitrators(
        address _accuser,
        address _accused
    ) private returns (address[] memory) {
        // Get N + 2 arbitrators, in case the accuser or accused come up in the list
        uint itemsToReturn = 1 + nodeQueueBackups; // Scoring node + backups
        uint itemsToFetch = itemsToReturn + 2; // allowance for accuser and accused

        address[] memory arbitrators = new address[](itemsToReturn);

        uint i = 0;
        while (arbitrators.length < itemsToReturn) {
            bytes32[] memory fetchedItems;
            (
                fetchedItems,
                nodeQueueArbitrationIndex,
                nodeQueueArbitrationCount
            ) = NodeQueueGetEntries(
                nodeQueueArbitrationIndex,
                itemsToFetch,
                nodeQueueArbitrationCount
            );

            AddressNumber memory currentItem = bytes32ToAddressNumber(
                fetchedItems[i]
            );
            if (
                currentItem.Address == _accuser ||
                currentItem.Address == _accused
            ) {
                continue;
            } else {
                arbitrators[i] = currentItem.Address;
            }
        }

        return arbitrators;
    }

    
}
