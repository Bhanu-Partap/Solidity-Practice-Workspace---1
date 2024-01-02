// SPDX-License-Identifier:MIT
pragma solidity ^0.8.17;

import "../NodeInfo/regionNodeQueues.sol";
import "./regionCompetition.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

abstract contract ourkadeCompetition is regionNodeQueues, regionCompetition {

    // Reputation variables
    // uint private MatchTimeLimit =  7*24*60*60; // default is 7 days
    // uint8 private CompetitionSlash = 25; // Default percent to slash for failed competition
    int16 internal RepInstantBan = -10000; // Dropping below this instantly bans the player

    //// Competition Storage
    using HitchensUnorderedKeySetLib for HitchensUnorderedKeySetLib.Set;

    mapping (bytes => uint8[]) internal CompetitionMatchCheck; // Key: Competition ID + Player Address. Value: Rounds in match
    mapping (bytes32 => uint[]) internal DisputedMatches; // Key: Competition ID. Value: The indices of matches disputed
    mapping (bytes => MatchDispute) internal MatchDisputes; // Key: Competition ID + Match Index. Value: Dispute details
    
    // Node Queue Storage
    uint nodeQueueScoringIndex; // Used to keep track of the next position in the competition scoring queue
	uint nodeQueueScoringCount = 1; // Used to keep track of additional slots the next node has. Default to 1 for first iteration
	uint nodeQueueArbitrationIndex; // Used to keep track of the next position in the arbitration scoring queue
	uint nodeQueueArbitrationCount; // Used to keep track of additional slots the next node has
    uint nodeQueueBackups = 2; // Number of additional nodes that can score

    function CreateCompetition(bytes calldata _competitionParamBytes) public {

		CompetitionParams memory _competitionParams = abi.decode(_competitionParamBytes, (CompetitionParams));

		_verifyGameDefinition(_competitionParams.GameDefinition);
		
		require(_getGameDefinition(_competitionParams.GameDefinition).Status == GameDefinitionStatus.Created, "GAME_NOT_ACTIVE");
		require(_competitionParams.MatchDuration <= MatchTimeLimit, "INVALID_DURATION");

		// If it's an Ourkade Admin then
		// competitions can be created without checking balances
		// if it's a player, balances are checked and they can only give away tickets

		if(!hasRole(ROLE_ADMIN, msg.sender)) {
			require(_competitionParams.CurrencyType == CurrencyType.Ticket, "INVALID_REWARD");

			// Validate the balance of the creator
			PlayerProfile storage creator = _getPlayerProfile(msg.sender);

			require(creator.Tickets >= _competitionParams.PrizePool, "INSUFFICIENT_BALANCE");

			creator.Tickets -= _competitionParams.PrizePool;
			emit LogPlayerProfile(msg.sender, msg.sender, ChangeType.Updated, creator);
		}

		// Calculate the ID and insert it
		bytes32 competitionId = createPlayerCompetitionId(msg.sender);
		competitionLookup.insert(competitionId);

		// Initialize the slot
		Competition storage newCompetition = competitions[competitionId];
		newCompetition.CompetitionId = competitionId;
		newCompetition.GameDefinition = _competitionParams.GameDefinition;

		newCompetition.EligibleByTicket = _competitionParams.EligibleByTicket;
		newCompetition.EligibleLoyalty = _competitionParams.EligibleLoyalty;
		newCompetition.EligibleReputation = _competitionParams.EligibleReputation;
		newCompetition.EligibleRankMinimum = _competitionParams.EligibleRankMinimum;
		newCompetition.EligibleRankMaximum = _competitionParams.EligibleRankMaximum;
		newCompetition.EligibleEloMinimum = _competitionParams.EligibleEloMinimum;
		newCompetition.EligibleEloMaximum = _competitionParams.EligibleEloMaximum;

		newCompetition.PrizeType = _competitionParams.PrizeType;
		newCompetition.PrizePool = _competitionParams.PrizePool;
		newCompetition.NodeReward = _competitionParams.NodeReward;
		newCompetition.EntryFee = _competitionParams.EntryFee;
		newCompetition.MinimumPlayers = _competitionParams.MinimumPlayers;
		newCompetition.MaximumPlayers = _competitionParams.MaximumPlayers;
		newCompetition.Status = CompetitionStatus.Created;
		newCompetition.EndTime = block.timestamp + _competitionParams.MatchDuration;
		newCompetition.MatchDuration = _competitionParams.MatchDuration;
		newCompetition.MatchesPerRound = _competitionParams.MatchesPerRound;
		// We're not doing any effort to have the judges be from different nodes
		// The purpose of the additional judges it to allow fail protection for nodes
		// that go offline and then allow the matches to be score by someone else
		// if someone puts all their nodes on at the same time and they're in the same
		// network, and then they all get selected as judged and are unable to score
		// due to the same network issue, then the account owner will pay the penalty
		// multiple times when all of their nodes fail to score.
		(newCompetition.Judges, nodeQueueScoringIndex, nodeQueueScoringCount) = NodeQueueGetEntries(nodeQueueScoringIndex, 1 + nodeQueueBackups, nodeQueueScoringCount);
	//	console.log("nodeQueueScoringIndex set to: %s", nodeQueueScoringIndex);
	//	console.log("nodeQueueScoringCount set to: %s", nodeQueueScoringCount);

		emit LogCompetition(msg.sender, competitionId, ChangeType.Created, newCompetition);
	}

    function ArchiveCompetition(bytes32 _competitionId, bytes calldata _pinId) private {
		require(_pinId.length > 0, "DATA_PIN_EMPTY");

		Competition storage competition = _getCompetition(_competitionId);

		// Unwind - First match disputes, then disputed matches, then competition match checks
		for (uint i = 0; i < DisputedMatches[_competitionId].length; i++) {
			delete MatchDisputes[createMatchDisputeId(_competitionId, i)];
		}

		delete DisputedMatches[_competitionId];
	
		for (uint i = 0; i < competition.Matches.length; i++) {
			// It's more efficient to just delete the same index multiple times than to optimize deletes
			// until we are duplicating deletes 500+ times, which is not the case for our matches
			delete CompetitionMatchCheck[createMatchCheckId(_competitionId, competition.Matches[i].Player)];
		}

		// Null the array to save space in world state
		_removeCompetition(_competitionId);
	}

    function _competitionIdToOwner(bytes32 _competitionId) private pure returns(address) {
		return address(bytes20(_competitionId));
	}

	function _cancelCompetition(bytes32 _competitionId) internal {
		Competition storage foundCompetition = _getCompetition(_competitionId);

		for (uint i = 0; i < foundCompetition.Matches.length; i++) {
			// Refund entry fees to all users
			Match storage currentMatch = foundCompetition.Matches[i];
			PlayerProfile storage currentPlayer = _getPlayerProfile(addressToBytes32(currentMatch.Player), true, false); // Refund even if they have been disabled
			currentPlayer.Tickets += foundCompetition.EntryFee;
		}

		if (!hasRole(ROLE_ADMIN, msg.sender)) {
			uint slashAmount = _calculateUnsignedPercent(foundCompetition.PrizePool, CompetitionSlash);
			PlayerProfile storage competitionOwner = _getPlayerProfile(addressToBytes32(_competitionIdToOwner(_competitionId)), true, false); // Refund even if they have been disabled
			competitionOwner.Tickets += foundCompetition.PrizePool - slashAmount;
		}

		foundCompetition.Status = CompetitionStatus.Disabled;
		
		emit LogCompetition(msg.sender, foundCompetition.CompetitionId, ChangeType.Disabled, foundCompetition);
	}

    function CancelCompetition(bytes32 _competitionId) public {
		address competitionOwner = _competitionIdToOwner(_competitionId);

		// Only owner can invoke directly
		// Anyone can trigger "Score" which may call Cancel
		require(competitionOwner == msg.sender, "NO_PERMISSION");

		_cancelCompetition(_competitionId);
	}

    // Determines if a player has another 
	function HasAnotherMatch(address _player, bytes memory _competitionId) private view returns(bool) {

	}

	function HasAnotherMatch(bytes calldata _competitionId) public view returns(bool) {
		return HasAnotherMatch(msg.sender, _competitionId);
	}

    function CanJoinCompetition(address _player, bytes32 _competitionId, bytes32 _ticketHash) private view returns(bool) {
		PlayerProfile storage currentPlayer = _getPlayerProfile(_player);
		Competition storage currentCompetition = _getCompetition(_competitionId);
		
		bytes32 correctTicketHash = keccak256(abi.encode(CompetitionTicket(_competitionId, currentPlayer.PlayerProfileId)));

		// First check Reputation
		// It must be above the minimum
		assert(currentPlayer.Reputation > RepInstantBan);
		// It must also be within the range of the competition
		if (!(currentPlayer.Reputation >= currentCompetition.EligibleReputation)) { return false;}
		
		// First check tickets
		if (currentCompetition.EligibleByTicket) {
			if (!SignatureChecker.isValidSignatureNow(_competitionIdToOwner(_competitionId),correctTicketHash, bytes.concat(_ticketHash))) { 
					return false;
			}
		}

		// Then check Loyalty
		if (!(currentPlayer.Loyalty >= currentCompetition.EligibleLoyalty)) { return false;}


		// Then check Rank
		// Default will be 0
		uint8 playerGameRank = _getPlayerGameRank(currentPlayer.PlayerProfileId, currentCompetition.GameDefinition);
		if (!(playerGameRank >= currentCompetition.EligibleRankMinimum)) { return false;}
		if (!(playerGameRank <= currentCompetition.EligibleRankMaximum)) { return false;}

		// Check the player has enough tickets
		if (currentPlayer.Tickets < currentCompetition.EntryFee) {
			return false;
		}

		return true;
	}

    function _createDraftMatch(uint8 _round) private view returns (Match memory) {
		return Match("0x0", _round, msg.sender, 0, MatchStatus.Created, block.timestamp, 0);
	}

	function _deductTickets(address _player, uint _tickets) private {
		PlayerProfile storage currentPlayer = _getPlayerProfile(_player);
		currentPlayer.Tickets -= _tickets;
	}

    // The player registers for the match and receives the info to start
	function RegisterForMatch(bytes32 _competitionId, bytes32 _ticketHash) public {
		require(CanJoinCompetition(msg.sender, _competitionId, _ticketHash), "MATCH_NOT_ELIGIBLE");

		uint8 currentMatchCount = uint8(_countCompetitionPlayerMatches(_competitionId, msg.sender));
		Competition storage foundCompetition = _getCompetition(_competitionId);
		
		require(currentMatchCount < foundCompetition.MatchesPerRound, "MATCH_EXHAUSTED");

		_deductTickets(msg.sender, foundCompetition.EntryFee);

		// Create a new pending match and insert it
		_insertCompetitionPlayerMatch(_competitionId, _createDraftMatch(currentMatchCount+1));
	}

    function _getSortedScores(bytes32 _competitionId, uint _count) internal view returns (uint[] memory) {
		Competition storage foundCompetition = _getCompetition(_competitionId);
		require(_count <= foundCompetition.Matches.length, "INSUFFICIENT_MATCHES");
		require(_count == 1, "UNSUPPORTED_SORT");

		uint[] memory scoreIndices = new uint[](_count);

		uint highestScore;
		uint highestIndex;
		uint returnCount;

		for (uint i = 0; i < foundCompetition.Matches.length; i++) {
			if (foundCompetition.Matches[i].Status != MatchStatus.Disabled &&
				foundCompetition.Matches[i].Score > highestScore) {
				highestScore = foundCompetition.Matches[i].Score;
				highestIndex = i;
			}
		}

		scoreIndices[returnCount++] = highestIndex;

		return scoreIndices;

	}


    // The player returns their submitted match. There's a time limit here.
	function SubmitMatch(bytes32 _competitionId, bytes calldata _dataPin, uint _score) public {
		// Get the match and make sure it's a match (Not default value)
		bytes memory matchCheckId = createMatchCheckId(_competitionId, msg.sender);
		uint8[] storage playerMatches = CompetitionMatchCheck[matchCheckId];
		uint8 currentMatchIndex = playerMatches[playerMatches.length-1];

		Competition storage foundCompetition = _getCompetition(_competitionId);
		Match storage currentMatch = foundCompetition.Matches[currentMatchIndex];

		//console.log("end time: %s", foundCompetition.EndTime);
		//console.log("block timestamp: %s", block.timestamp);
		require(block.timestamp < foundCompetition.EndTime, "COMPETITION_CLOSED");
		
		// This means the last match has already been submitted
		require(currentMatch.Status == MatchStatus.Created, "MATCH_SUBMISSION_INVALID");

		// This means the user took too long to submit the match
		require(currentMatch.EndTime < currentMatch.StartTime + foundCompetition.MatchDuration, "MATCH_EXPIRED");
		
		currentMatch.Status = MatchStatus.Pending;
		currentMatch.DataPin = _dataPin;
		currentMatch.Score = _score;
		currentMatch.EndTime = block.timestamp;

		// Add data for tracking scores
		if (foundCompetition.PrizeType == PrizeType.WinnerTakeAll) {

		} else {
			revert("COMPETITION_TYPE_NOT_IMPLEMENTED");
		}

		// Update Player's last Match
		_getPlayerProfile(msg.sender).LastGameTimestamp = block.timestamp;

		// Check if there's another match
		if (foundCompetition.MatchesPerRound > currentMatchIndex) {
			_insertCompetitionPlayerMatch(_competitionId, _createDraftMatch(currentMatchIndex+1));
		}

		// Rank and ELO are not updated until the match is successfully scored
	}

// ------------------------------------------------------------------------------------------------
    // This function inserts a match without validation.
	// Caller must validate the match can be added.
	function _insertCompetitionPlayerMatch(bytes32 _competitionId, Match memory _match) private {
		Competition storage foundCompetition = _getCompetition(_competitionId);
		bytes memory lookupId = createMatchCheckId(_competitionId, _match.Player);
		uint8 nextMatch = uint8(foundCompetition.Matches.length);

		if (CompetitionMatchCheck[lookupId].length == 0) {
			foundCompetition.Players.push(_match.Player);
		}

		CompetitionMatchCheck[lookupId].push(nextMatch);
		foundCompetition.Matches.push(_match);

		emit LogCompetition(msg.sender, _competitionId, ChangeType.Updated, foundCompetition);
	}

    function _countCompetitionPlayerMatches(bytes32 _competitionId, address _player) private view returns(uint8) {
		return uint8(CompetitionMatchCheck[createMatchCheckId(_competitionId, _player)].length);
	}
    function createPlayerCompetitionId(address _player) internal returns(bytes32) {
		return bytes32(bytes.concat(bytes20(msg.sender), bytes12(NextCompetitionNonce(_player))));
	}
}