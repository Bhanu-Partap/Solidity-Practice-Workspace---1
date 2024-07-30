// SPDX-License-Identifier:MIT
pragma solidity ^0.8.17;

import "../Helpers/crudMethods.sol";
import "../Helpers/helpers.sol";
import "@openzeppelin/contracts/utils/structs/DoubleEndedQueue.sol";
import "../Helpers/configuration.sol";

abstract contract regionProfile is crudMethods, Helper, configuration {
    uint32 constant seconds_in_day = 86400;
    uint256 currentDay;

    using HitchensUnorderedKeySetLib for HitchensUnorderedKeySetLib.Set;
    HitchensUnorderedKeySetLib.Set internal playerProfileLookup;

    mapping(bytes32 => PlayerProfile) internal playerProfiles;
    mapping(address => uint256) playerLastActivity;
    mapping(bytes32 => mapping(bytes32 => DoubleEndedQueue.Bytes32Deque)) private PlayerGameScores; // Score queue of last X games and use for averaging
    mapping(bytes32 => mapping(bytes32 => uint256)) PlayerGameElo;
    mapping(bytes32 => mapping(bytes32 => uint8)) private PlayerGameRank;

    event LogPlayerProfile(
        address indexed sender,
        address indexed key,
        ChangeType indexed change,
        PlayerProfile profile
    );

    /* #region Profiles */
    function _createPlayerProfile(address key) internal {
        _createPlayerProfile(addressToBytes32(key));
    }

    function _createPlayerProfile(bytes32 key) private {
        playerProfileLookup.insert(key);
        PlayerProfile storage newItem = playerProfiles[key];

        newItem.PlayerProfileId = key;
        newItem.Status = PlayerProfileStatus.Created;
        // newItem.Tickets = 0;
        // newItem.AvailableBalance = 0;
        // newItem.CompetitionNonce = 0;

        // Also set the daily data to the current date to shorten the loop
        playerLastActivity[bytes32ToAddress(key)] = _getDay();

        emit LogPlayerProfile(
            msg.sender,
            bytes32ToAddress(key),
            ChangeType.Created,
            newItem
        );
    }

    function checkPlayerProfile(address key) public view returns (bool) {
        return checkPlayerProfile(addressToBytes32(key));
    }

    function checkPlayerProfile(bytes32 key) public view returns (bool) {
        return playerProfileLookup.exists(key);
    }

    function _verifyPlayerProfile(address key) private view {
        _verifyPlayerProfile(addressToBytes32(key));
    }

    function _verifyPlayerProfile(bytes32 key) private view {
        require(checkPlayerProfile(key) == true, "PROFILE_DOES_NOT_EXIST");
    }

    function _getPlayerProfile(address key)
        internal view
        returns (PlayerProfile storage)
    {
        return _getPlayerProfile(addressToBytes32(key));
    }

    function _getPlayerProfile(address key, bool getDisabled)
        internal view
        returns (PlayerProfile storage)
    {
        return _getPlayerProfile(addressToBytes32(key), getDisabled, false);
    }

    function _getPlayerProfile(bytes32 key)
        internal view
        returns (PlayerProfile storage)
    {
        return _getPlayerProfile(key, false, false);
    }

    function _getPlayerProfile(
        bytes32 key,
        bool getDisabled,
        bool skipDaily
    ) internal view  returns (PlayerProfile storage) {
        // We have to verify, because array lookup won't fail if it's null
        _verifyPlayerProfile(key);
        PlayerProfile storage item = playerProfiles[key];

        if (
            getDisabled == false && item.Status == PlayerProfileStatus.Disabled
        ) {
            revert("PROFILE_DISABLED");
        }

        if (skipDaily == false) {
            // ---------------------------Error------------------------
            // _playerRepUpdate(item);
        }

        return item;
    }

    function GetPlayerProfile(address key)
        public view
        returns (PlayerProfile memory)
    {
        return _getPlayerProfile(addressToBytes32(key), true, false);
    }

    function GetPlayerProfile(bytes32 key)
        public view 
        returns (PlayerProfile memory)
    {
        return _getPlayerProfile(key, true, false);
    }

    function GetPlayerProfileCount() public view returns (uint256 count) {
        return playerProfileLookup.count();
    }

    function GetPlayerProfileAtIndex(uint256 index)
        public
        view
        returns (bytes32 key)
    {
        return playerProfileLookup.keyAtIndex(index);
    }

    function _addPlayerGameScore(
        bytes32 _player,
        bytes32 _gameDefinition,
        uint256 _newScore
    ) internal {
        uint8 PlayerEloMemory = 20;
        DoubleEndedQueue.pushFront(
            PlayerGameScores[_player][_gameDefinition],
            bytes32(_newScore)
        );

        // Allow storage to be resized later
        // Normally should only be one iteration
        while (
            DoubleEndedQueue.length(
                PlayerGameScores[_player][_gameDefinition]
            ) > PlayerEloMemory
        ) {
            DoubleEndedQueue.popBack(
                PlayerGameScores[_player][_gameDefinition]
            );
        }

        PlayerGameElo[_player][_gameDefinition] = _calculatePlayerGameElo(
            _player,
            _gameDefinition
        );
    }

    function _calculatePlayerGameElo(bytes32 _player, bytes32 _gameDefinition)
        private
        view
        returns (uint256)
    {
        uint256 scoreSum;
        uint256 scoreCount = DoubleEndedQueue.length(
            PlayerGameScores[_player][_gameDefinition]
        );

        for (uint256 i = 0; i < scoreCount; i++) {
            scoreSum += uint256(
                DoubleEndedQueue.at(
                    PlayerGameScores[_player][_gameDefinition],
                    i
                )
            );
        }

        return scoreSum / scoreCount;
    }

    function _getPlayerElo(bytes32 _gameDefinition, bytes32 _player)
        private
        view
        returns (uint256)
    {
        return PlayerGameElo[_player][_gameDefinition];
    }

    function _getPlayerGameRank(bytes32 _gameDefinition, bytes32 _player)
        internal
        view
        returns (uint8)
    {
        return PlayerGameRank[_player][_gameDefinition];
    }

    // For now, only Ourkade admins can set player ranks
    function _setPlayerGameRank(
        bytes32 _gameDefinition,
        address _player,
        uint8 _rank
    ) private onlyRole(ROLE_ADMIN) {
        _verifyGameDefinition(_gameDefinition);
        PlayerProfile storage profile = _getPlayerProfile(_player); // This will also verify

        PlayerGameRank[addressToBytes32(_player)][_gameDefinition] = _rank;

        emit LogPlayerProfile(msg.sender, _player, ChangeType.Updated, profile);
    }

    // Function to allow bulk updating of player ranks because this will need
    // to be done by admins, likely from a service
    function SetPlayerGameRanks(
        bytes32[] calldata _gameDefinition,
        address[] calldata _player,
        uint8[] calldata _rank
    ) public onlyRole(ROLE_ADMIN) {
        require(
            _gameDefinition.length == _player.length &&
                _gameDefinition.length == _rank.length,
            "INVALID_UPDATE"
        );
        for (uint256 i = 0; i < _player.length; i++) {
            _setPlayerGameRank(_gameDefinition[i], _player[i], _rank[i]);
        }
    }

    /* #endregion */

    function _getDay() internal returns (uint256) {
        if ((block.timestamp / seconds_in_day) > currentDay) {
            currentDay = block.timestamp - (block.timestamp % seconds_in_day);
        }
        return currentDay;
    }

    // Returns 12 bits, so the nonce address + nonce fit in 32 bytes
	function NextCompetitionNonce(address _sender) internal returns(uint96) {
		PlayerProfile storage currentPlayer = _getPlayerProfile(_sender);
		currentPlayer.CompetitionNonce += 1;
		return currentPlayer.CompetitionNonce - 1;
	}

    
}
