// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {ourkadelib} from "../library/ourkadelib.sol";
import "../Types.sol";

contract OurkadePlayer  {
    modifier isWallet() {
        require(msg.sender == tx.origin, "WALLETS_ONLY");
        _;
    }

   

    /// Internal Functions
    // Returns 12 bits, so the nonce address + nonce fit in 32 bytes
    function NextCompetitionNonce(address _sender) private returns (uint96) {
        return ourkadelib.NextCompetitionNonce(_sender);
    }

    function _checkCompetitionPlayerHasNoMatches(
        bytes32 _competitionId,
        address _player
    ) private view returns (bool) {
        return
            ourkadelib._checkCompetitionPlayerHasNoMatches(
                _competitionId,
                _player
            );
    }

    function _countCompetitionPlayerMatches(
        bytes32 _competitionId,
        address _player
    ) private view returns (uint8) {
        return
            ourkadelib._countCompetitionPlayerMatches(_competitionId, _player);
    }

    // This function inserts a match without validation.
    // Caller must validate the match can be added.
    function _insertCompetitionPlayerMatch(
        bytes32 _competitionId,
        Match memory _match
    ) private {
        ourkadelib._insertCompetitionPlayerMatch(_competitionId, _match);
    }

    /* #endregion */

    /* #region Profiles */

    function _createPlayerProfile(address key) private {
        ourkadelib._createPlayerProfile(key);
    }

    function _createPlayerProfile(bytes32 key) private {
        ourkadelib._createPlayerProfile(key);
    }

    function _removePlayerProfile(address key) private {
        ourkadelib._removePlayerProfile(key);
    }

    function _removePlayerProfile(bytes32 key) private {
        ourkadelib._removePlayerProfile(key);
    }

    function checkPlayerProfile(address key) public view returns (bool) {
        return ourkadelib.checkPlayerProfile(key);
    }

    function checkPlayerProfile(bytes32 key) public view returns (bool) {
        return ourkadelib.checkPlayerProfile(key);
    }

    function _verifyPlayerProfile(address key) private view {
        ourkadelib._verifyPlayerProfile(key);
    }

    function _verifyPlayerProfile(bytes32 key) private view {
        ourkadelib._verifyPlayerProfile(key);
    }

    function _getPlayerProfile(
        address key
    ) internal returns (PlayerProfile storage) {
        return ourkadelib._getPlayerProfile(key);
    }

    function _getPlayerProfile(
        address key,
        bool getDisabled
    ) internal returns (PlayerProfile storage) {
        return ourkadelib._getPlayerProfile(key, getDisabled);
    }

    function _getPlayerProfile(
        bytes32 key
    ) internal returns (PlayerProfile storage) {
        return ourkadelib._getPlayerProfile(key);
    }

    function _getPlayerProfile(
        bytes32 key,
        bool getDisabled,
        bool skipDaily
    ) internal returns (PlayerProfile storage) {
        // We have to verify, because array lookup won't fail if it's null
        return ourkadelib._getPlayerProfile(key, getDisabled, skipDaily);
    }

    function GetPlayerProfile(
        address key
    ) public returns (PlayerProfile memory) {
        return ourkadelib.GetPlayerProfile(key);
    }

    function GetPlayerProfile(
        bytes32 key
    ) public returns (PlayerProfile memory) {
        return ourkadelib.GetPlayerProfile(key);
    }

    function GetPlayerProfileCount() public view returns (uint256 count) {
        return ourkadelib.GetPlayerProfileCount();
    }

    function GetPlayerProfileAtIndex(
        uint256 index
    ) public view returns (bytes32 key) {
        return ourkadelib.GetPlayerProfileAtIndex(index);
    }

    function _addPlayerGameScore(
        bytes32 _player,
        bytes32 _gameDefinition,
        uint256 _newScore
    ) private {
        ourkadelib._addPlayerGameScore(_player, _gameDefinition, _newScore);
    }

    function _calculatePlayerGameElo(
        bytes32 _player,
        bytes32 _gameDefinition
    ) private view returns (uint256) {
        return ourkadelib._calculatePlayerGameElo(_player, _gameDefinition);
    }

    function _getPlayerElo(
        bytes32 _gameDefinition,
        bytes32 _player
    ) private view returns (uint256) {
        return ourkadelib._getPlayerElo(_gameDefinition, _player);
    }

    function _getPlayerGameRank(
        bytes32 _gameDefinition,
        bytes32 _player
    ) private view returns (uint8) {
        return ourkadelib._getPlayerGameRank(_gameDefinition, _player);
    }

    function CreateProfile() public isWallet {
        ourkadelib.CreateProfile();
    }

    // Determines if a player has another
    function HasAnotherMatch(
        address _player,
        bytes memory _competitionId
    ) private view returns (bool) {}

    function HasAnotherMatch(
        bytes calldata _competitionId
    ) public view returns (bool) {
        return ourkadelib.HasAnotherMatch(_competitionId);
    }

    function CanJoinCompetition(
        address _player,
        bytes32 _competitionId,
        bytes32 _ticketHash
    ) private returns (bool) {
        return
            ourkadelib.CanJoinCompetition(_player, _competitionId, _ticketHash);
    }

    function _createDraftMatch(
        uint8 _round
    ) private view returns (Match memory) {
        return ourkadelib._createDraftMatch(_round);
    }

    function _deductTickets(address _player, uint256 _tickets) private {
        ourkadelib._deductTickets(_player, _tickets);
    }

    // The player registers for the match and receives the info to start

    function RegisterForMatch(
        bytes32 _competitionId,
        bytes32 _ticketHash
    ) public {
        ourkadelib.RegisterForMatch(_competitionId, _ticketHash);
    }

    function _getSortedScores(
        bytes32 _competitionId,
        uint256 _count
    ) private view returns (uint256[] memory) {
        return ourkadelib._getSortedScores(_competitionId, _count);
    }

    // The player returns their submitted match. There's a time limit here.
    function SubmitMatch(
        bytes32 _competitionId,
        bytes calldata _dataPin,
        uint256 _score
    ) public {
        ourkadelib.SubmitMatch(_competitionId, _dataPin, _score);
        // Rank and ELO are not updated until the match is successfully scored
    }

    function _calculateLoyalty(
        address _player,
        int32 _reputation,
        uint16 _addMinutes
    ) private view returns (uint64) {
        return ourkadelib._calculateLoyalty(_player, _reputation, _addMinutes);
    }

    function _addPlayerLoyalty(address _player, uint16 _addMinutes) private {
        ourkadelib._addPlayerLoyalty(_player, _addMinutes);
    }

    function _addPlayerReputation(address _player, int32 _add) private {
        ourkadelib._addPlayerReputation(_player, _add);
    }

    function _calculateIdleReputationLoss(
        int32 _startingRep,
        uint16 _days
    ) private pure returns (int32) {
        return ourkadelib._calculateIdleReputationLoss(_startingRep, _days);
    }

    function ScoreCompetition(
        bytes32 _competitionId,
        uint96 _nodeNumber
    ) public {
        ourkadelib.ScoreCompetition(_competitionId, _nodeNumber);
    }

    function _calculatePenalty(
        uint256 _innocentVotes,
        uint256 _guiltyVotes,
        uint256 _guiltyCount
    ) private view returns (uint16) {
        return
            ourkadelib._calculatePenalty(
                _innocentVotes,
                _guiltyVotes,
                _guiltyCount
            );
    }

    function _nodeQueueJoin(address key, uint96 nodeId) private {
        ourkadelib._nodeQueueJoin(key, nodeId);
    }

    function MatchDisputeCalculateStatus(
        bytes32 _competitionId,
        uint256 _matchIndex
    ) public view returns (MatchDisputeStatus) {
        return
            ourkadelib.MatchDisputeCalculateStatus(_competitionId, _matchIndex);
    }

    // Upon dispute creation, determine the dispute admin
    // Admin cannot be the accuser, accused, or vote on the dispute
    // Voters sign a message with the Admin's public key which includes: Competition, Address, Vote, + other hash?
    // When dispute is resolved, admin decrypts votes and tallys them
    // Voter can dispute decrypted value?
    //		Or by forcing admin to reveal secret (then we should use a different encrypting key which can be rerolled)

    function MatchDisputeResolve(
        bytes32 _competitionId,
        uint256 _matchIndex,
        VoteType[] memory _revealedVotes
    ) public {
        ourkadelib.MatchDisputeResolve(
            _competitionId,
            _matchIndex,
            _revealedVotes
        );
    }

    ////
    //// Reputation (Clout) Functions
    ////

    // We don't need a function for "can join competition" because
    // competitions set their own join criteria, including Reputation.

    // Accepts a reputation and returns a node earning percentage
    function _playerRepNodeEarning(
        int32 _reputation
    ) private pure returns (uint8) {
        return ourkadelib._playerRepNodeEarning(_reputation);
    }

    // Accepts a reputation and returns a loyalty earning multiplier
    function _playerRepLoyaltyMultiplier(
        int32 _reputation
    ) private pure returns (uint8) {
        return ourkadelib._playerRepLoyaltyMultiplier(_reputation);
    }

    // The Flag, Vote, and Update functions all depend on the day
    // They will compare the player's current allowable flags
    // ,which is based on reputation, and the number of times they
    // have flagged already. If it's not allow, this will revert
    // This function assumes _playerRepUpdate has been called already
    // which will ensure the daily reset happens
    function _playerRepFlag(address _player, int32 _reputation) private {
        ourkadelib._playerRepFlag(_player, _reputation);
    }

    function _playerRepVote(address _player, int32 _reputation) private {
        ourkadelib._playerRepVote(_player, _reputation);
    }

    function _playerRepBuyNode(int32 _reputation) private view {
        ourkadelib._playerRepBuyNode(_reputation);
    }

    // // This function will be called every time and will
    // // only perform updates when necessary.
    // // This will allow the profile to be updated if it's
    // // disabled, which means the caller needs to check that
    function _playerRepUpdate(PlayerProfile storage _profile) private {
        ourkadelib._playerRepUpdate(_profile);
    }

    function _getDay() private returns (uint256) {
        return ourkadelib._getDay();
    }
}
