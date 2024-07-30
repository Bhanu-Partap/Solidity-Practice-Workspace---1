/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/structs/DoubleEndedQueue.sol";
import "@openzeppelin/contracts/utils/Strings.sol"; // For debugging
import "./HitchensUnorderedKeySet.sol";
import "./accesslib.sol";
import "../Types.sol";

library ourkadelib {
    bytes32 constant OURKADE_POSITION = keccak256("ourkade.storage");
    bytes32 constant ROLE_ADMIN = keccak256("OURKADE_ADMIN");
    bytes32 constant DEFAULT_ADMIN_ROLE = bytes32(0);
    bytes32 constant ROLE_OPERATOR = keccak256("OURKADE_OPERATOR");
    using HitchensUnorderedKeySetLib for HitchensUnorderedKeySetLib.Set;
    using accesslib for accesslib.roles;
    using ECDSA for bytes32;

    struct Storage {
        // Storage
        //// Player Profile Storage

        accesslib.roles OURKADE;
        HitchensUnorderedKeySetLib.Set playerProfileLookup;
        mapping(bytes32 => PlayerProfile) playerProfiles;
        //// Competition Storage
        HitchensUnorderedKeySetLib.Set competitionLookup;
        mapping(bytes32 => Competition) competitions;
        //// Game Storage
        HitchensUnorderedKeySetLib.Set gameDefinitionLookup;
        mapping(bytes32 => GameDefinition) gameDefinitions;
        //// Node Info Storage
        HitchensUnorderedKeySetLib.Set nodeInfoLookup;
        mapping(bytes32 => NodeInfo) nodeInfos;
        //// Node Queue Storage
        HitchensUnorderedKeySetLib.Set nodeQueueLookup; // The set of nodes in the queue, in sequence
        bytes32[] nodeQueueLeaveList; // Use to track the nodes to be removed from queue on next compact
        mapping(bytes32 => bool) nodeQueueLeaveCheck; // Used to check if a node is queued to be removed
        uint256 nodeQueueScoringIndex; // Used to keep track of the next position in the competition scoring queue
        uint256 nodeQueueScoringCount; // Used to keep track of additional slots the next node has. Default to 1 for first iteration
        uint256 nodeQueueArbitrationIndex; // Used to keep track of the next position in the arbitration scoring queue
        uint256 nodeQueueArbitrationCount; // Used to keep track of additional slots the next node has
        //// Node Queue Settings
        uint256 nodeQueueTierCount; // Number of node tiers in existence. Could be optimized.
        mapping(uint256 => uint64) nodeQueueTierFees; // Fee to join each queue. Index is queue number.
        mapping(uint256 => uint256) nodeQueueTierTurns; // The number of turns granted by each tier;
        uint256 nodeQueueBackups; // Number of additional nodes that can score
        uint256 nodeQueueBackupDelay; // Time that each backup has to wait. Nth backup has to wait N * BackupDelay
        uint256 nodeQueueCompactLimit;
        mapping(bytes => uint8[]) CompetitionMatchCheck; // Key: Competition ID + Player Address. Value: Rounds in match
        mapping(bytes32 => uint256[]) DisputedMatches; // Key: Competition ID. Value: The indices of matches disputed
        mapping(bytes => MatchDispute) MatchDisputes; // Key: Competition ID + Match Index. Value: Dispute details
        mapping(address => uint16) DailyMinutesPlayed; // Used to track daily matches and calculate loyalty
        mapping(bytes32 => mapping(bytes32 => uint8)) PlayerGameRank; // Store map of players and their ranks for games
        mapping(bytes32 => mapping(bytes32 => DoubleEndedQueue.Bytes32Deque)) PlayerGameScores; // Score queue of last X games and use for averaging
        mapping(bytes32 => mapping(bytes32 => uint256)) PlayerGameElo;
        // Temporal data
        uint256 currentDay;
        mapping(address => uint256) playerLastActivity;
        mapping(address => uint256) playerLastCalcLookup;
        mapping(address => uint256) playerDailyVotes;
        mapping(address => uint256) playerDailyFlags;
        uint256 seconds_in_day;
        // Configuration
        uint8 CompetitionSlash; // Default percent to slash for failed competition
        // Reputation variables
        uint256 DisputeVotesRequired;
        uint256 DisputeWindow; // How long (in seconds) after a match is submitted that it can be disputed. Default: 3 hours
        uint256 DisputeDuration; // How long (in seconds) after creation until dispute can be closed. Default: 2 days
        uint256 DisputeExpiry; // How long (in seconds) after dispute closure until it's expired. Default is: 1 days
        uint32 RepAdjustVoteDispute; // The reputation it costs to vote on a dispute
        uint32 RepAdjustRightAccuse; // Reputation gain for accusing correctly
        uint32 RepAdjustWrongAccuse; // Reputation loss for accusing incorrectly
        uint32 RepAdjustRightVote; // Reputation gain for voting correctly
        uint32 RepAdjustWrongVote; // Reputation loss for voting incorrectly
        uint32 RepAdjustFinishMatch; // Reputation for completing a match undisputed
        int32 RepInstantBan; // Dropping below this instantly bans the player
        uint8 RepGuiltyLimit; // This many guilty verdits instantly bans the player
        uint256 MatchTimeLimit; // default is 7 days
        uint64[] LoyaltyLookup; // Index: minute of play, Value: Reward for play
        uint8 PlayerEloMemory; // Number of matches to store in each player's ELO queue
        uint8 RepToZeroDays; // Number of days until rep is automatically set to 0.
        uint32 NodeBuyRepRequired; // Reputation required to buy a node
        uint32 NodeBuyRepFloor; // Reputation
    }

    event LogNodeQueueJoin(address indexed sender, bytes32 indexed key);
    event LogNodeQueueLeave(address indexed sender, bytes32 indexed key);
    event LogNodeQueueRebuild(address indexed sender);
    event LogNodeInfo(
        address indexed sender,
        bytes32 indexed key,
        ChangeType indexed change,
        NodeInfo info
    );
    event LogPlayerProfile(
        address indexed sender,
        address indexed key,
        ChangeType indexed change,
        PlayerProfile profile
    );
    event LogGame(
        address indexed sender,
        bytes32 indexed key,
        ChangeType indexed change,
        GameDefinition game
    );
    event LogCompetition(
        address indexed sender,
        bytes32 indexed key,
        ChangeType indexed change,
        Competition competition
    );
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

    function getStorage() internal pure returns (Storage storage ds) {
        bytes32 position = OURKADE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function constantdata() internal {
        Storage storage ds = getStorage();
        ds.nodeQueueScoringCount = 1; // Used to keep track of additional slots the next node has. Default to 1 for first iteration

        ds.nodeQueueBackups = 2; // Number of additional nodes that can score
        ds.nodeQueueBackupDelay = 10; // Time that each backup has to wait. Nth backup has to wait N * BackupDelay
        ds.nodeQueueCompactLimit = 10;

        ds.seconds_in_day = 86400;

        ds.CompetitionSlash = 25; // Default percent to slash for failed competition

        ds.DisputeVotesRequired = 50;
        ds.DisputeWindow = 3 * 60 * 60; // How long (in seconds) after a match is submitted that it can be disputed. Default: 3 hours
        ds.DisputeDuration = 2 * 24 * 60 * 60; // How long (in seconds) after creation until dispute can be closed. Default: 2 days
        ds.DisputeExpiry = 1 * 24 * 60 * 60; // How long (in seconds) after dispute closure until it's expired. Default is: 1 days
        ds.RepAdjustVoteDispute = 200; // The reputation it costs to vote on a dispute
        ds.RepAdjustRightAccuse = 800; // Reputation gain for accusing correctly
        ds.RepAdjustWrongAccuse = 0; // Reputation loss for accusing incorrectly
        ds.RepAdjustRightVote = 400; // Reputation gain for voting correctly
        ds.RepAdjustWrongVote = 0; // Reputation loss for voting incorrectly
        ds.RepAdjustFinishMatch = 100; // Reputation for completing a match undisputed
        ds.RepInstantBan = -10000; // Dropping below this instantly bans the player
        ds.RepGuiltyLimit = 3; // This many guilty verdits instantly bans the player
        ds.MatchTimeLimit = 7 * 24 * 60 * 60; // default is 7 days

        ds.PlayerEloMemory = 20; // Number of matches to store in each player's ELO queue

        ds.RepToZeroDays = 33; // Number of days until rep is automatically set to 0.
        ds.NodeBuyRepRequired = 0; // Reputation required to buy a node
        ds.NodeBuyRepFloor = 10000; // Reputation granted when getting a node.
    }

// here we are adding a function in new contract

      function setRepGuiltyLimit(uint8 guiltylimit) internal {
        Storage storage ds = getStorage();
        ds.RepGuiltyLimit = guiltylimit;
    }

     function readRepGuiltyLimit() internal view returns(uint8) {
         Storage storage ds = getStorage();
         return ds.RepGuiltyLimit;}


    function IsAccessAdmin(address _address) internal view returns (bool) {
        Storage storage ds = getStorage();
        return ds.OURKADE.hasRole(DEFAULT_ADMIN_ROLE, _address);
    }

    function IsOurkadeAdmin(address _address) internal view returns (bool) {
        Storage storage ds = getStorage();
        return ds.OURKADE.hasRole(ROLE_ADMIN, _address);
    }

    function IsOurkadeOperator(address _address) internal view returns (bool) {
        Storage storage ds = getStorage();
        return ds.OURKADE.hasRole(ROLE_OPERATOR, _address);
    }

    function checkrole(bytes32 role) internal view {
        Storage storage ds = getStorage();
        ds.OURKADE._checkRole(role);
    }

    function setAdminRole(bytes32 role1, bytes32 role2) internal {
        Storage storage ds = getStorage();
        ds.OURKADE._setRoleAdmin(role1, role2);
    }

    function AddOurkadeAdmin(address _address) internal returns (bool) {
        Storage storage ds = getStorage();
        ds.OURKADE.grantRole(ROLE_ADMIN, _address);
        return true;
    }

    function DEFAULT_ADMIN(address _address) internal returns (bool) {
        Storage storage ds = getStorage();
        ds.OURKADE._grantRole(DEFAULT_ADMIN_ROLE, _address);
        return true;
    }

    function RemoveOurkadeAdmin(address _address) internal returns (bool) {
        Storage storage ds = getStorage();
        ds.OURKADE.revokeRole(ROLE_ADMIN, _address);
        return true;
    }

    function AddOurkadeOperator(address _address) internal returns (bool) {
        Storage storage ds = getStorage();
        ds.OURKADE.grantRole(ROLE_OPERATOR, _address);
        return true;
    }

    function RemoveOurkadeOperator(address _address) internal returns (bool) {
        Storage storage ds = getStorage();
        ds.OURKADE.revokeRole(ROLE_OPERATOR, _address);
        return true;
    }

    // Helper Functions
    // Returns right-aligned address
    function addressToBytes32(address a) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(a)));
    }

    // Gets right-aligned address
    function bytes32ToAddress(bytes32 b) internal pure returns (address) {
        return address(uint160(uint256(b)));
    }

    function addressDataToBytes32(
        AddressData memory ad
    ) internal pure returns (bytes32) {
        return bytes32(bytes.concat(ad.Data, bytes20(ad.Address)));
    }

    function bytes32ToAddressData(
        bytes32 b
    ) internal pure returns (AddressData memory) {
        return AddressData(bytes12(b), bytes32ToAddress(b));
    }

    function addressNumberToBytes32(
        AddressNumber memory ad
    ) internal pure returns (bytes32) {
        return bytes32(bytes.concat(bytes12(ad.Number), bytes20(ad.Address)));
    }

    function bytes32ToAddressNumber(
        bytes32 b
    ) internal pure returns (AddressNumber memory) {
        return AddressNumber(uint96(bytes12(b)), bytes32ToAddress(b));
    }

  

    // Returns 52 bytes
    function createMatchCheckId(
        bytes32 _competition,
        address _player
    ) internal pure returns (bytes memory) {
        return bytes.concat(_competition, bytes20(_player));
    }

    function createPlayerCompetitionId(
        address _player
    ) internal returns (bytes32) {
        return
            bytes32(
                bytes.concat(
                    bytes20(msg.sender),
                    bytes12(NextCompetitionNonce(_player))
                )
            );
    }

    // Returns 64 bytes - could be smaller?
    function createMatchDisputeId(
        bytes32 _competitionId,
        uint256 _matchIndex
    ) internal pure returns (bytes memory) {
        return bytes.concat(_competitionId, bytes32(_matchIndex));
    }

    /// Configuration Functions
    function SetCompetitionSlash(uint8 _value) internal {
        Storage storage ds = getStorage();
        require(_value <= 100, "INVALID_COMPETITION_SLASH");
        ds.CompetitionSlash = _value;
    }

    function SetDisputeDuration(uint256 _value) internal {
        Storage storage ds = getStorage();

        ds.DisputeDuration = _value;
    }

    function SetDisputeVotesRequired(uint256 _value) internal {
        Storage storage ds = getStorage();
        ds.DisputeVotesRequired = _value;
    }

    function SetRepAdjustRightAccuse(uint32 _value) internal {
        Storage storage ds = getStorage();
        ds.RepAdjustRightAccuse = _value;
    }

    function SetRepAdjustWrongAccuse(uint32 _value) internal {
        Storage storage ds = getStorage();
        ds.RepAdjustWrongAccuse = _value;
    }

    function SetMatchTimeLimit(uint256 _value) internal {
        Storage storage ds = getStorage();
        ds.MatchTimeLimit = _value;
    }

    function SetLoyaltyLookup(uint64[] calldata _value) internal {
        Storage storage ds = getStorage();

        ds.LoyaltyLookup = _value;
    }

    /// Internal Functions
    // Returns 12 bits, so the nonce address + nonce fit in 32 bytes
    function NextCompetitionNonce(address _sender) internal returns (uint96) {
        PlayerProfile storage currentPlayer = _getPlayerProfile(_sender);
        currentPlayer.CompetitionNonce += 1;
        return currentPlayer.CompetitionNonce - 1;
    }

    // From Uniswap v2
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _calculateUnsignedPercent(
        uint256 _number1,
        uint8 _percent
    ) internal pure returns (uint256) {
        return (_number1 * _percent) / 100;
    }

    function _calculatePercent(
        int256 _number1,
        uint8 _percent
    ) internal pure returns (int256) {
        return (_number1 * int8(_percent)) / 100;
    }

    function _checkCompetitionPlayerHasNoMatches(
        bytes32 _competitionId,
        address _player
    ) internal view returns (bool) {
        Storage storage ds = getStorage();

        return
            ds
                .CompetitionMatchCheck[
                    createMatchCheckId(_competitionId, _player)
                ]
                .length == 0;
    }

    function _countCompetitionPlayerMatches(
        bytes32 _competitionId,
        address _player
    ) internal view returns (uint8) {
        Storage storage ds = getStorage();

        return
            uint8(
                ds
                    .CompetitionMatchCheck[
                        createMatchCheckId(_competitionId, _player)
                    ]
                    .length
            );
    }

    // This function inserts a match without validation.
    // Caller must validate the match can be added.
    function _insertCompetitionPlayerMatch(
        bytes32 _competitionId,
        Match memory _match
    ) internal {
        Competition storage foundCompetition = _getCompetition(_competitionId);
        bytes memory lookupId = createMatchCheckId(
            _competitionId,
            _match.Player
        );
        uint8 nextMatch = uint8(foundCompetition.Matches.length);
        Storage storage ds = getStorage();

        if (ds.CompetitionMatchCheck[lookupId].length == 0) {
            foundCompetition.Players.push(_match.Player);
        }

        ds.CompetitionMatchCheck[lookupId].push(nextMatch);
        foundCompetition.Matches.push(_match);

        emit LogCompetition(
            msg.sender,
            _competitionId,
            ChangeType.Updated,
            foundCompetition
        );
    }

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
    function _createGameDefinition(
        bytes32 key,
        GameDefinition memory newItem
    ) internal {
        Storage storage ds = getStorage();
        ds.gameDefinitionLookup.insert(key);
        ds.gameDefinitions[key] = newItem;
        emit LogGame(msg.sender, key, ChangeType.Created, newItem);
    }

    function _removeGameDefinition(bytes32 key) internal {
        // This will fail automatically if the key doesn't exist
        Storage storage ds = getStorage();

        ds.gameDefinitionLookup.remove(key);
        GameDefinition memory removedItem = ds.gameDefinitions[key];
        delete ds.gameDefinitions[key];
        emit LogGame(msg.sender, key, ChangeType.Removed, removedItem);
    }

    function checkGameDefinition(bytes32 key) internal view returns (bool) {
        Storage storage ds = getStorage();
        return ds.gameDefinitionLookup.exists(key);
    }

    function _verifyGameDefinition(bytes32 key) internal view {
        require(checkGameDefinition(key) == true, "INVALID_GAME");
    }

    function _getGameDefinition(
        bytes32 key
    ) internal view returns (GameDefinition storage) {
        // We have to verify, because array lookup won't fail if it's null
        _verifyGameDefinition(key);
        Storage storage ds = getStorage();

        GameDefinition storage item = ds.gameDefinitions[key];
        return (item);
    }

    function getGameDefinition(
        bytes32 key
    ) internal view returns (GameDefinition memory) {
        return (_getGameDefinition(key));
    }

    function getGameDefinitionCount() internal view returns (uint256 count) {
        Storage storage ds = getStorage();
        return ds.gameDefinitionLookup.count();
    }

    function getGameDefinitionAtIndex(
        uint256 index
    ) internal view returns (bytes32 key) {
        Storage storage ds = getStorage();
        return ds.gameDefinitionLookup.keyAtIndex(index);
    }

    /* #endregion */

    /* #region Profiles */
    function _createPlayerProfile(address key) internal {
        _createPlayerProfile(addressToBytes32(key));
    }

    function _createPlayerProfile(bytes32 key) internal {
        Storage storage ds = getStorage();
        ds.playerProfileLookup.insert(key);
        PlayerProfile storage newItem = ds.playerProfiles[key];

        newItem.PlayerProfileId = key;
        newItem.Status = PlayerProfileStatus.Created;
        // newItem.Tickets = 0;
        // newItem.AvailableBalance = 0;
        // newItem.CompetitionNonce = 0;

        // Also set the daily data to the current date to shorten the loop

        ds.playerLastActivity[bytes32ToAddress(key)] = _getDay();

        emit LogPlayerProfile(
            msg.sender,
            bytes32ToAddress(key),
            ChangeType.Created,
            newItem
        );
    }

    function _removePlayerProfile(address key) internal {
        _removePlayerProfile(addressToBytes32(key));
    }

    function _removePlayerProfile(bytes32 key) internal {
        PlayerProfile storage removedItem = _getPlayerProfile(key);

        // Remove Nodes
        _removeNodeInfo(bytes32ToAddress(key), removedItem.NodeCount);

        // Disable Profile
        removedItem.Status = PlayerProfileStatus.Disabled;
        emit LogPlayerProfile(
            msg.sender,
            bytes32ToAddress(key),
            ChangeType.Disabled,
            removedItem
        );
    }

    function checkPlayerProfile(address key) internal view returns (bool) {
        return checkPlayerProfile(addressToBytes32(key));
    }

    function checkPlayerProfile(bytes32 key) internal view returns (bool) {
        Storage storage ds = getStorage();
        return ds.playerProfileLookup.exists(key);
    }

    function _verifyPlayerProfile(address key) internal view {
        _verifyPlayerProfile(addressToBytes32(key));
    }

    function _verifyPlayerProfile(bytes32 key) internal view {
        require(checkPlayerProfile(key) == true, "PROFILE_DOES_NOT_EXIST");
    }

    function _getPlayerProfile(
        address key
    ) internal returns (PlayerProfile storage) {
        return _getPlayerProfile(addressToBytes32(key));
    }

    function _getPlayerProfile(
        address key,
        bool getDisabled
    ) internal returns (PlayerProfile storage) {
        return _getPlayerProfile(addressToBytes32(key), getDisabled, false);
    }

    function _getPlayerProfile(
        bytes32 key
    ) internal returns (PlayerProfile storage) {
        return _getPlayerProfile(key, false, false);
    }

    function _getPlayerProfile(
        bytes32 key,
        bool getDisabled,
        bool skipDaily
    ) internal returns (PlayerProfile storage) {
        // We have to verify, because array lookup won't fail if it's null
        _verifyPlayerProfile(key);
        Storage storage ds = getStorage();

        PlayerProfile storage item = ds.playerProfiles[key];

        if (
            getDisabled == false && item.Status == PlayerProfileStatus.Disabled
        ) {
            revert("PROFILE_DISABLED");
        }

        if (skipDaily == false) {
            _playerRepUpdate(item);
        }

        return item;
    }

    function GetPlayerProfile(
        address key
    ) internal returns (PlayerProfile memory) {
        return _getPlayerProfile(addressToBytes32(key), true, false);
    }

    function GetPlayerProfile(
        bytes32 key
    ) internal returns (PlayerProfile memory) {
        return _getPlayerProfile(key, true, false);
    }

    function GetPlayerProfileCount() internal view returns (uint256 count) {
        Storage storage ds = getStorage();
        return ds.playerProfileLookup.count();
    }

    function GetPlayerProfileAtIndex(
        uint256 index
    ) internal view returns (bytes32 key) {
        Storage storage ds = getStorage();
        return ds.playerProfileLookup.keyAtIndex(index);
    }

    function _addPlayerGameScore(
        bytes32 _player,
        bytes32 _gameDefinition,
        uint256 _newScore
    ) internal {
        Storage storage ds = getStorage();
        DoubleEndedQueue.pushFront(
            ds.PlayerGameScores[_player][_gameDefinition],
            bytes32(_newScore)
        );

        // Allow storage to be resized later
        // Normally should only be one iteration
        while (
            DoubleEndedQueue.length(
                ds.PlayerGameScores[_player][_gameDefinition]
            ) > ds.PlayerEloMemory
        ) {
            DoubleEndedQueue.popBack(
                ds.PlayerGameScores[_player][_gameDefinition]
            );
        }

        ds.PlayerGameElo[_player][_gameDefinition] = _calculatePlayerGameElo(
            _player,
            _gameDefinition
        );
    }

    function _calculatePlayerGameElo(
        bytes32 _player,
        bytes32 _gameDefinition
    ) internal view returns (uint256) {
        Storage storage ds = getStorage();

        uint256 scoreSum;
        uint256 scoreCount = DoubleEndedQueue.length(
            ds.PlayerGameScores[_player][_gameDefinition]
        );

        for (uint256 i = 0; i < scoreCount; i++) {
            scoreSum += uint256(
                DoubleEndedQueue.at(
                    ds.PlayerGameScores[_player][_gameDefinition],
                    i
                )
            );
        }

        return scoreSum / scoreCount;
    }

    function _getPlayerElo(
        bytes32 _gameDefinition,
        bytes32 _player
    ) internal view returns (uint256) {
        Storage storage ds = getStorage();
        return ds.PlayerGameElo[_player][_gameDefinition];
    }

    function _getPlayerGameRank(
        bytes32 _gameDefinition,
        bytes32 _player
    ) internal view returns (uint8) {
        Storage storage ds = getStorage();
        return ds.PlayerGameRank[_player][_gameDefinition];
    }

    // For now, only Ourkade admins can set player ranks
    function _setPlayerGameRank(
        bytes32 _gameDefinition,
        address _player,
        uint8 _rank
    ) internal {
        Storage storage ds = getStorage();
        _verifyGameDefinition(_gameDefinition);
        PlayerProfile storage profile = _getPlayerProfile(_player); // This will also verify

        ds.PlayerGameRank[addressToBytes32(_player)][_gameDefinition] = _rank;

        emit LogPlayerProfile(msg.sender, _player, ChangeType.Updated, profile);
    }

    // Function to allow bulk updating of player ranks because this will need
    // to be done by admins, likely from a service
    function SetPlayerGameRanks(
        bytes32[] calldata _gameDefinition,
        address[] calldata _player,
        uint8[] calldata _rank
    ) internal {
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

    /* #region  Competitions */
    function _createCompetition(
        bytes32 key,
        Competition memory newItem
    ) internal {
        Storage storage ds = getStorage();
        // Not implemented due to special logic
        ds.competitionLookup.insert(key);
        ds.competitions[key] = newItem;
        emit LogCompetition(msg.sender, key, ChangeType.Created, newItem);
    }

    function _removeCompetition(bytes32 key) internal {
        // This will fail automatically if the key doesn't exist
        Storage storage ds = getStorage();

        Competition memory removedItem = ds.competitions[key];
        ds.competitionLookup.remove(key);
        delete ds.competitions[key];
        emit LogCompetition(msg.sender, key, ChangeType.Removed, removedItem);
    }

    function checkCompetition(bytes32 key) internal view returns (bool) {
        Storage storage ds = getStorage();
        return ds.competitionLookup.exists(key);
    }

    function _verifyCompetition(bytes32 key) internal view {
        require(checkCompetition(key) == true, "COMPETITION_DOES_NOT_EXIST");
    }

    function _getCompetition(
        bytes32 key
    ) internal view returns (Competition storage) {
        // We have to verify, because array lookup won't fail if it's null
        _verifyCompetition(key);
        Storage storage ds = getStorage();

        Competition storage item = ds.competitions[key];
        return (item);
    }

    function getCompetition(
        bytes32 key
    ) internal view returns (Competition memory) {
        return (_getCompetition(key));
    }

    function getCompetitionCount() internal view returns (uint256 count) {
        Storage storage ds = getStorage();
        return ds.competitionLookup.count();
    }

    function getCompetitionAtIndex(
        uint256 index
    ) internal view returns (bytes32 key) {
        Storage storage ds = getStorage();
        return ds.competitionLookup.keyAtIndex(index);
    }

    /* #endregion */

    /* #region NodeInfo */
    function _createNodeInfo(address _player, uint96 _count) internal {
        Storage storage ds = getStorage();
        require(_count > 0, "NODE_INVALID_QUANTITY");

        PlayerProfile storage targetPlayer = _getPlayerProfile(_player);

        // Check if the player has enough reputation to buy a node
        // This should really be stopped on the front-end until it's full web3
        // This is just a double check
        _playerRepBuyNode(targetPlayer.Reputation);

        require(
            _count + targetPlayer.NodeCount < type(uint96).max,
            "NODE_INVALID_QUANTITY"
        );

        for (uint96 i = 1; i <= _count; i++) {
            bytes32 newId = addressNumberToBytes32(
                AddressNumber({
                    Address: _player,
                    Number: ++targetPlayer.NodeCount
                })
            );

            ds.nodeInfoLookup.insert(newId);
            NodeInfo storage newItem = ds.nodeInfos[newId];

            newItem.PlayerProfileId = _player;
            newItem.NodeId = targetPlayer.NodeCount;
            newItem.Status = NodeInfoStatus.Inactive;

            emit LogNodeInfo(msg.sender, newId, ChangeType.Created, newItem);
        }

        // Update the player's rep to the floor for node owners
        //console.log("Reputation before: %s", Strings.toString(uint(int256(targetPlayer.Reputation))));
        //console.log("Node buy rep floor: %s", Strings.toString(uint(NodeBuyRepFloor)));
        if (targetPlayer.Reputation < int32(ds.NodeBuyRepFloor)) {
            targetPlayer.Reputation = int32(ds.NodeBuyRepFloor);
            //console.log("Reputation after: %s", Strings.toString(uint(int256(targetPlayer.Reputation))));
        }

        emit LogPlayerProfile(
            msg.sender,
            _player,
            ChangeType.Updated,
            targetPlayer
        );
    }

    function _nodeStakeQueueTier(address _player, uint96 _nodeNumber) internal {
        PlayerProfile storage currentPlayer = _getPlayerProfile(_player);
        NodeInfo storage currentNode = _getNodeInfo(_player, _nodeNumber);

        uint256 nextTier = currentNode.LoyaltyLocked.length;
        uint64 tierFee;
        (tierFee, ) = NodeQueueTierGet(nextTier);

        require(currentPlayer.Loyalty >= tierFee, "INSUFFICIENT_LOYALTY");

        currentPlayer.Loyalty -= tierFee;

        currentNode.LoyaltyLocked.push(tierFee);

        // No other action is needed. The function to get items from the queue
        // checks how many turns a node should get. If the player stakes before
        // it is their turn then they get the extra turn this cycle
        // If they stake during or after their turn, it will be applied next cycle

        emit LogPlayerProfile(
            msg.sender,
            _player,
            ChangeType.Updated,
            currentPlayer
        );
    }

    function _nodeUnstakeQueueTier(
        address _player,
        uint96 _nodeNumber
    ) internal {
        PlayerProfile storage currentPlayer = _getPlayerProfile(_player);
        NodeInfo storage currentNode = _getNodeInfo(_player, _nodeNumber);

        uint256 leaveTier = currentNode.LoyaltyLocked.length - 1;

        currentPlayer.Loyalty += currentNode.LoyaltyLocked[leaveTier];

        currentNode.LoyaltyLocked.pop();

        // If they've left the last tier turn the node offline
        if (leaveTier == 0 && currentNode.Status == NodeInfoStatus.Active) {
            // Is this a gas issue to fetch the same data twice?
            _nodeStatusOffline(_player, _nodeNumber);
        }

        emit LogPlayerProfile(
            msg.sender,
            _player,
            ChangeType.Updated,
            currentPlayer
        );
    }

    function _removeNodeInfo(address _player, uint96 _count) internal {
        PlayerProfile storage targetPlayer = _getPlayerProfile(_player);

        require(_count <= targetPlayer.NodeCount, "NODE_INVALID");

        for (uint96 i = 0; i < _count; i++) {
            uint96 currentNodeNumber = targetPlayer.NodeCount - i; // Start by removing the last node
            bytes32 removeId = addressNumberToBytes32(
                AddressNumber({Address: _player, Number: currentNodeNumber})
            );

            NodeInfo storage removedItem = _getNodeInfo(
                _player,
                currentNodeNumber
            );

            for (uint256 x = 0; x < removedItem.LoyaltyLocked.length; x++) {
                _nodeUnstakeQueueTier(_player, currentNodeNumber);
            }

            if (removedItem.Status == NodeInfoStatus.Active) {
                _nodeStatusOffline(_player, currentNodeNumber);
            }
            Storage storage ds = getStorage();

            ds.nodeInfoLookup.remove(removeId);
            delete ds.nodeInfos[removeId];

            emit LogNodeInfo(
                msg.sender,
                removeId,
                ChangeType.Removed,
                removedItem
            );
        }

        targetPlayer.NodeCount -= _count;

        emit LogPlayerProfile(
            msg.sender,
            _player,
            ChangeType.Updated,
            targetPlayer
        );
    }

    function checkNodeInfo(
        address key,
        uint96 nodeId
    ) internal view returns (bool) {
        Storage storage ds = getStorage();
        bytes32 checkId = addressNumberToBytes32(
            AddressNumber({Address: key, Number: nodeId})
        );
        return ds.nodeInfoLookup.exists(checkId);
    }

    function _verifyNodeInfo(address key, uint96 nodeId) internal view {
        require(checkNodeInfo(key, nodeId) == true, "NODE_INFO_DOES_NOT_EXIST");
    }

    function _getNodeInfo(
        address key,
        uint96 nodeId
    ) internal view returns (NodeInfo storage) {
        bytes32 getId = addressNumberToBytes32(
            AddressNumber({Address: key, Number: nodeId})
        );
        // We have to verify, because array lookup won't fail if it's null
        _verifyNodeInfo(key, nodeId);
        Storage storage ds = getStorage();

        NodeInfo storage item = ds.nodeInfos[getId];

        return (item);
    }

    function GetNodeInfo(
        address key,
        uint96 nodeId
    ) internal view returns (NodeInfo memory) {
        return _getNodeInfo(key, nodeId);
    }

    function GetNodeInfoCount() internal view returns (uint256 count) {
        Storage storage ds = getStorage();
        return ds.nodeInfoLookup.count();
    }

    function GetNodeIdAtIndex(
        uint256 index
    ) internal view returns (bytes32 key) {
        Storage storage ds = getStorage();
        return ds.nodeInfoLookup.keyAtIndex(index);
    }

    /* #endregion */

    /* #region Node Queues */
    // This "queue" is using a set to track unique items
    // and a position to track where it is in the "queue"
    // The operations are more restricted:
    // - join queue: a node joins the queue
    // - leave queue: a node leaves the queue
    // - get from queue: get x items starting at y position (wraps around)
    // - count queue: gets the count of items in the queue

    // This should return the number of turns a node gets in the queue based on its staking
    function _nodeQueueTurns(
        address _operator,
        uint96 _nodeNumber
    ) internal view returns (uint256) {
        // The turns per tier is stored as a total number
        // so we just need to find out which tier the node is staked to
        // which is the length of their locked loyalty
        NodeInfo storage currentNode = _getNodeInfo(_operator, _nodeNumber);
        Storage storage ds = getStorage();

        return ds.nodeQueueTierTurns[currentNode.LoyaltyLocked.length - 1];
    }

    function _nodeQueueJoin(address key, uint96 nodeId) internal {
        bytes32 lookupId = addressNumberToBytes32(
            AddressNumber({Address: key, Number: nodeId})
        );
        _verifyNodeInfo(key, nodeId);
        Storage storage ds = getStorage();

        // If they are queued to leave, just clear it so they stay in the queue
        if (ds.nodeQueueLeaveCheck[lookupId] == true) {
            ds.nodeQueueLeaveCheck[lookupId] = false;
        } else {
            // otherwise add them to the queue
            // Update Lookup
            // This should throw an error if it's already in the queue
            ds.nodeQueueLookup.insert(lookupId);
        }

        // Emit the event in either case, because the leave event is emitted when
        // they request to leave
        emit LogNodeQueueJoin(msg.sender, lookupId);
    }

    // This actually just flags the node for removal upon next compact
    // The function to get entries will ignore offline nodes
    function _nodeQueueLeave(address key, uint96 nodeId) internal {
        bytes32 lookupId = addressNumberToBytes32(
            AddressNumber({Address: key, Number: nodeId})
        );
        _verifyNodeInfo(key, nodeId);
        Storage storage ds = getStorage();

        require(ds.nodeQueueLeaveCheck[lookupId] == false, "ALREADY_QUEUED");

        ds.nodeQueueLeaveCheck[lookupId] = true;
        ds.nodeQueueLeaveList.push(lookupId);

        emit LogNodeQueueLeave(msg.sender, lookupId);
    }

    // This should not be used in practice, because if the queue is compacted before
    // it has completed a cycle then it will result in an uneven distribution of turns
    function NodeQueueCompact() internal {
        _nodeQueueCompact();
    }

    function _nodeQueueCompact() internal {
        Storage storage ds = getStorage();

        //console.log("_nodeQueueCompact called");
        uint256 queueLength = ds.nodeQueueLeaveList.length;
        //console.log("leave queueLength: %s", queueLength);
        //console.log("node queueLength: %s", nodeQueueLookup.count());

        // Don't allow too many to be removed at a time to avoid running out of gas
        uint256 removeCount = queueLength > ds.nodeQueueCompactLimit
            ? ds.nodeQueueCompactLimit
            : queueLength;
        //console.log("removeCount: %s", removeCount);

        for (uint256 i = 1; i <= removeCount; i++) {
            //console.log("in loop: %s", i);
            bytes32 removeId = ds.nodeQueueLeaveList[queueLength - i];
            //console.log("removeId: %s", Strings.toHexString(uint256(removeId)));

            // Remove from queue
            ds.nodeQueueLookup.remove(removeId);

            // Remove from compact lists
            ds.nodeQueueLeaveCheck[removeId] = false;
            ds.nodeQueueLeaveList.pop();
            //console.log("new leave queue length: %s", nodeQueueLeaveList.length);
            //console.log("new node queueLength: %s", nodeQueueLookup.count());
        }
    }

    // DEBUG function. Should be removed later
    // Returns the count of IDs from the queue
    function GetNodeQueueIds(
        uint256 _count
    ) internal view returns (bytes32[] memory) {
        Storage storage ds = getStorage();

        bytes32[] memory returnItems = new bytes32[](_count);
        for (uint256 i = 0; i < _count; i++) {
            bytes32 currentId = ds.nodeQueueLookup.keyAtIndex(i);
            returnItems[i] = currentId;
            // AddressNumber memory nextAddressNumber = bytes32ToAddressNumber(currentId);
            // returnItems[i] = nextAddressNumber.Address;
        }

        return returnItems;
    }

    // It's the responsibility of the caller to track where to start from
    // Caller is responsible to update index and remaining turns if necessary
    // Allowing this to be external for testing and transparency
    // Returns the list of entries, next index, remaining turns for next index
    function NodeQueueGetEntries(
        uint256 start,
        uint256 count,
        uint256 initialRemainingTurns
    ) internal returns (bytes32[] memory, uint256, uint256) {
        //console.log("NodeQueueGetEntries called");
        //console.log("start: %s", start);
        //console.log("count: %s", count);
        //console.log("initial remaining: %s", initialRemainingTurns);

        // for (uint i = 0; i < count; i++) {
        // //	console.log("node at index %s: %s", i, Strings.toHexString(uint(nodeQueueLookup.keyAtIndex(i))));
        // }

        uint256 queueLength = NodeQueueGetLength();
        // Can't get node entries from an empty queue
        require(queueLength > 0, "NODE_QUEUE_EMPTY");
        // Can't set start location outside of queue
        require(start < queueLength, "NODE_QUEUE_INVALID_START");

        uint256 currentIndex = start;
        uint256 currentCount = 0;
        Storage storage ds = getStorage();

        bytes32[] memory returnItems = new bytes32[](count);

        uint256 currentRemainingTurns = initialRemainingTurns;

        bytes32 currentId = ds.nodeQueueLookup.keyAtIndex(currentIndex);

        uint256 debugIteration = 0;
        while (currentCount < count) {
            debugIteration++;
            // if the node is not scheduled to leave then add it to the list
            // this saves us the gas of looking up the node info to check the status
            while (currentRemainingTurns > 0 && currentCount < count) {
                if (ds.nodeQueueLeaveCheck[currentId] == true) {
                    currentRemainingTurns = 0; // Short-circuit if node is offline
                    //console.log("Skipping offline node: ", Strings.toHexString(uint256(currentId)));
                } else {
                    //console.log("iteration %s: setting %s to %s", debugIteration, currentCount, Strings.toHexString(uint(currentId)));
                    returnItems[currentCount] = currentId;
                    currentCount++;
                    currentRemainingTurns--;
                }
            }

            // If there are turns remaining then we have filled the
            // request but didn't exhaust the current node
            // so we should not change the index or remaining item count
            if (currentRemainingTurns == 0) {
                // Increment or wrap index
                if (currentIndex == queueLength - 1) {
                    currentIndex = 0;

                    // Compact the queue
                    _nodeQueueCompact();
                    queueLength = NodeQueueGetLength();
                } else {
                    currentIndex++;
                }

                currentId = ds.nodeQueueLookup.keyAtIndex(currentIndex);
                AddressNumber memory nextAddressNumber = bytes32ToAddressNumber(
                    currentId
                );
                currentRemainingTurns = _nodeQueueTurns(
                    nextAddressNumber.Address,
                    nextAddressNumber.Number
                );
            }
        }

        //console.log("Returning index: %s", currentIndex);
        //console.log("Remaining turns: %s", currentRemainingTurns);
        // for (uint i = 0; i < returnItems.length; i++) {
        // //	console.log("returnItem at index %s: %s", Strings.toHexString(uint(returnItems[i])), i);
        // }

        return (returnItems, currentIndex, currentRemainingTurns);
    }

    function NodeQueueGetLength() internal view returns (uint256) {
        Storage storage ds = getStorage();
        return ds.nodeQueueLookup.count();
    }

    /* #endregion */

    // Only Admins
    function CreateGameDefinition(
        bytes32 _id,
        string calldata _name,
        bool _isMultiplayer
    ) internal returns (bool) {
        require(bytes(_name).length != 0, "INVALID_GAME_NAME");
        require(bytes(_name).length <= 1024, "INVALID_GAME_NAME");

        _createGameDefinition(
            _id,
            GameDefinition(
                _id,
                _name,
                _isMultiplayer,
                GameDefinitionStatus.Created
            )
        );

        return true;
    }

    // This will just prevent new competitions being created for this game
    function DisableGameDefinition(bytes32 _id) internal {
        GameDefinition storage gameDefinition = _getGameDefinition(_id);

        require(
            gameDefinition.Status == GameDefinitionStatus.Created,
            "GAME_NOT_ACTIVE"
        );

        gameDefinition.Status = GameDefinitionStatus.Disabled;

        emit LogGame(msg.sender, _id, ChangeType.Disabled, gameDefinition);
    }

    function DepositTickets(address _target, uint256 _addTickets) internal {
        require(_addTickets > 0, "INVALID_TICKET_DEPOSIT");
        PlayerProfile storage profile = _getPlayerProfile(_target);
        profile.Tickets += _addTickets;
        emit LogPlayerProfile(msg.sender, _target, ChangeType.Updated, profile);
    }

    function AdminCreateProfile(address _target) internal {
        _createPlayerProfile(_target);
    }

    // Only admins can do this, and it should only be in exceptional cases
    // where guilty count was increased due to a mistake, or a
    // community-voted "amnesty" plan
    // No checks on it going negative, since Guilty Count is unsigned
    // will need to be called multiple times to reduce the amount to 0
    function AdminExcuseProfile(address _target) internal {
        PlayerProfile storage profile = _getPlayerProfile(_target);
        profile.GuiltyCount -= 1;
        emit LogPlayerProfile(msg.sender, _target, ChangeType.Updated, profile);
    }

    // In case an account is completely banned they will need a full reset
    function AdminAbsolveProfile(address _target) internal {
        PlayerProfile storage profile = _getPlayerProfile(
            addressToBytes32(_target),
            true,
            false
        );
        profile.GuiltyCount = 0;
        profile.LastGuiltyTimestamp = 0;
        profile.Reputation = 0;
        profile.Status == PlayerProfileStatus.Created;
        emit LogPlayerProfile(msg.sender, _target, ChangeType.Enabled, profile);
    }

    function CreateProfile() internal {
        _createPlayerProfile(msg.sender);
    }

    function CreateCompetition(bytes calldata _competitionParamBytes) internal {
        Storage storage ds = getStorage();
        CompetitionParams memory _competitionParams = abi.decode(
            _competitionParamBytes,
            (CompetitionParams)
        );

        _verifyGameDefinition(_competitionParams.GameDefinition);

        require(
            _getGameDefinition(_competitionParams.GameDefinition).Status ==
                GameDefinitionStatus.Created,
            "GAME_NOT_ACTIVE"
        );
        require(
            _competitionParams.MatchDuration <= ds.MatchTimeLimit,
            "INVALID_DURATION"
        );

        // If it's an Ourkade Admin then
        // competitions can be created without checking balances
        // if it's a player, balances are checked and they can only give away tickets

        if (!ds.OURKADE.hasRole(ROLE_ADMIN, msg.sender)) {
            require(
                _competitionParams.CurrencyType == CurrencyType.Ticket,
                "INVALID_REWARD"
            );

            // Validate the balance of the creator
            PlayerProfile storage creator = _getPlayerProfile(msg.sender);

            require(
                creator.Tickets >= _competitionParams.PrizePool,
                "INSUFFICIENT_BALANCE"
            );

            creator.Tickets -= _competitionParams.PrizePool;

            emit LogPlayerProfile(
                msg.sender,
                msg.sender,
                ChangeType.Updated,
                creator
            );
        }

        // Calculate the ID and insert it
        bytes32 competitionId = createPlayerCompetitionId(msg.sender);
        ds.competitionLookup.insert(competitionId);

        // Initialize the slot
        Competition storage newCompetition = ds.competitions[competitionId];
        newCompetition.CompetitionId = competitionId;
        newCompetition.GameDefinition = _competitionParams.GameDefinition;

        newCompetition.EligibleByTicket = _competitionParams.EligibleByTicket;
        newCompetition.EligibleLoyalty = _competitionParams.EligibleLoyalty;
        newCompetition.EligibleReputation = _competitionParams
            .EligibleReputation;
        newCompetition.EligibleRankMinimum = _competitionParams
            .EligibleRankMinimum;
        newCompetition.EligibleRankMaximum = _competitionParams
            .EligibleRankMaximum;
        newCompetition.EligibleEloMinimum = _competitionParams
            .EligibleEloMinimum;
        newCompetition.EligibleEloMaximum = _competitionParams
            .EligibleEloMaximum;

        newCompetition.PrizeType = _competitionParams.PrizeType;
        newCompetition.PrizePool = _competitionParams.PrizePool;
        newCompetition.NodeReward = _competitionParams.NodeReward;
        newCompetition.EntryFee = _competitionParams.EntryFee;
        newCompetition.MinimumPlayers = _competitionParams.MinimumPlayers;
        newCompetition.MaximumPlayers = _competitionParams.MaximumPlayers;
        newCompetition.Status = CompetitionStatus.Created;
        newCompetition.EndTime =
            block.timestamp +
            _competitionParams.MatchDuration;
        newCompetition.MatchDuration = _competitionParams.MatchDuration;
        newCompetition.MatchesPerRound = _competitionParams.MatchesPerRound;
        // We're not doing any effort to have the judges be from different nodes
        // The purpose of the additional judges it to allow fail protection for nodes
        // that go offline and then allow the matches to be score by someone else
        // if someone puts all their nodes on at the same time and they're in the same
        // network, and then they all get selected as judged and are unable to score
        // due to the same network issue, then the account owner will pay the penalty
        // multiple times when all of their nodes fail to score.
        (
            newCompetition.Judges,
            ds.nodeQueueScoringIndex,
            ds.nodeQueueScoringCount
        ) = NodeQueueGetEntries(
            ds.nodeQueueScoringIndex,
            1 + ds.nodeQueueBackups,
            ds.nodeQueueScoringCount
        );
        //	console.log("nodeQueueScoringIndex set to: %s", nodeQueueScoringIndex);
        //	console.log("nodeQueueScoringCount set to: %s", nodeQueueScoringCount);

        emit LogCompetition(
            msg.sender,
            competitionId,
            ChangeType.Created,
            newCompetition
        );
    }

    function ArchiveCompetition(
        bytes32 _competitionId,
        bytes calldata _pinId
    ) internal {
        require(_pinId.length > 0, "DATA_PIN_EMPTY");
        Storage storage ds = getStorage();

        Competition storage competition = _getCompetition(_competitionId);

        // Unwind - First match disputes, then disputed matches, then competition match checks
        for (
            uint256 i = 0;
            i < ds.DisputedMatches[_competitionId].length;
            i++
        ) {
            delete ds.MatchDisputes[createMatchDisputeId(_competitionId, i)];
        }

        delete ds.DisputedMatches[_competitionId];

        for (uint256 i = 0; i < competition.Matches.length; i++) {
            // It's more efficient to just delete the same index multiple times than to optimize deletes
            // until we are duplicating deletes 500+ times, which is not the case for our matches
            delete ds.CompetitionMatchCheck[
                createMatchCheckId(
                    _competitionId,
                    competition.Matches[i].Player
                )
            ];
        }

        // Null the array to save space in world state
        _removeCompetition(_competitionId);
    }

    function _competitionIdToOwner(
        bytes32 _competitionId
    ) internal pure returns (address) {
        return address(bytes20(_competitionId));
    }

    function _cancelCompetition(bytes32 _competitionId) internal {
        Competition storage foundCompetition = _getCompetition(_competitionId);

        for (uint256 i = 0; i < foundCompetition.Matches.length; i++) {
            // Refund entry fees to all users
            Match storage currentMatch = foundCompetition.Matches[i];
            PlayerProfile storage currentPlayer = _getPlayerProfile(
                addressToBytes32(currentMatch.Player),
                true,
                false
            ); // Refund even if they have been disabled
            currentPlayer.Tickets += foundCompetition.EntryFee;
        }
        Storage storage ds = getStorage();
        if (ds.OURKADE.hasRole(ROLE_ADMIN, msg.sender)) {
            uint256 slashAmount = _calculateUnsignedPercent(
                foundCompetition.PrizePool,
                ds.CompetitionSlash
            );
            PlayerProfile storage competitionOwner = _getPlayerProfile(
                addressToBytes32(_competitionIdToOwner(_competitionId)),
                true,
                false
            ); // Refund even if they have been disabled
            competitionOwner.Tickets +=
                foundCompetition.PrizePool -
                slashAmount;
        }

        foundCompetition.Status = CompetitionStatus.Disabled;

        emit LogCompetition(
            msg.sender,
            foundCompetition.CompetitionId,
            ChangeType.Disabled,
            foundCompetition
        );
    }

    function CancelCompetition(bytes32 _competitionId) internal {
        address competitionOwner = _competitionIdToOwner(_competitionId);

        // Only owner can invoke directly
        // Anyone can trigger "Score" which may call Cancel
        require(competitionOwner == msg.sender, "NO_PERMISSION");

        _cancelCompetition(_competitionId);
    }

    // Determines if a player has another
    function HasAnotherMatch(
        address _player,
        bytes memory _competitionId
    ) internal view returns (bool) {}

    function HasAnotherMatch(
        bytes calldata _competitionId
    ) internal view returns (bool) {
        return HasAnotherMatch(msg.sender, _competitionId);
    }

    function CanJoinCompetition(
        address _player,
        bytes32 _competitionId,
        bytes32 _ticketHash
    ) internal returns (bool) {
        Storage storage ds = getStorage();
        PlayerProfile storage currentPlayer = _getPlayerProfile(_player);
        Competition storage currentCompetition = _getCompetition(
            _competitionId
        );

        bytes32 correctTicketHash = keccak256(
            abi.encode(
                CompetitionTicket(_competitionId, currentPlayer.PlayerProfileId)
            )
        );

        // First check Reputation
        // It must be above the minimum
        assert(currentPlayer.Reputation > ds.RepInstantBan);
        // It must also be within the range of the competition
        if (
            !(currentPlayer.Reputation >= currentCompetition.EligibleReputation)
        ) {
            return false;
        }

        // First check tickets
        if (currentCompetition.EligibleByTicket) {
            if (
                !SignatureChecker.isValidSignatureNow(
                    _competitionIdToOwner(_competitionId),
                    correctTicketHash,
                    bytes.concat(_ticketHash)
                )
            ) {
                return false;
            }
        }

        // Then check Loyalty
        if (!(currentPlayer.Loyalty >= currentCompetition.EligibleLoyalty)) {
            return false;
        }

        // Then check Rank
        // Default will be 0
        uint8 playerGameRank = _getPlayerGameRank(
            currentPlayer.PlayerProfileId,
            currentCompetition.GameDefinition
        );
        if (!(playerGameRank >= currentCompetition.EligibleRankMinimum)) {
            return false;
        }
        if (!(playerGameRank <= currentCompetition.EligibleRankMaximum)) {
            return false;
        }

        // Check the player has enough tickets
        if (currentPlayer.Tickets < currentCompetition.EntryFee) {
            return false;
        }

        return true;
    }

    function _createDraftMatch(
        uint8 _round
    ) internal view returns (Match memory) {
        return
            Match(
                "0x0",
                _round,
                msg.sender,
                0,
                MatchStatus.Created,
                block.timestamp,
                0
            );
    }

    function _deductTickets(address _player, uint256 _tickets) internal {
        PlayerProfile storage currentPlayer = _getPlayerProfile(_player);
        currentPlayer.Tickets -= _tickets;
    }

    // The player registers for the match and receives the info to start
    function RegisterForMatch(
        bytes32 _competitionId,
        bytes32 _ticketHash
    ) internal {
        require(
            CanJoinCompetition(msg.sender, _competitionId, _ticketHash),
            "MATCH_NOT_ELIGIBLE"
        );

        uint8 currentMatchCount = uint8(
            _countCompetitionPlayerMatches(_competitionId, msg.sender)
        );
        Competition storage foundCompetition = _getCompetition(_competitionId);

        require(
            currentMatchCount < foundCompetition.MatchesPerRound,
            "MATCH_EXHAUSTED"
        );

        _deductTickets(msg.sender, foundCompetition.EntryFee);

        // Create a new pending match and insert it
        _insertCompetitionPlayerMatch(
            _competitionId,
            _createDraftMatch(currentMatchCount + 1)
        );
    }

    function _getSortedScores(
        bytes32 _competitionId,
        uint256 _count
    ) internal view returns (uint256[] memory) {
        Competition storage foundCompetition = _getCompetition(_competitionId);
        require(
            _count <= foundCompetition.Matches.length,
            "INSUFFICIENT_MATCHES"
        );
        require(_count == 1, "UNSUPPORTED_SORT");

        uint256[] memory scoreIndices = new uint256[](_count);

        uint256 highestScore;
        uint256 highestIndex;
        uint256 returnCount;

        for (uint256 i = 0; i < foundCompetition.Matches.length; i++) {
            if (
                foundCompetition.Matches[i].Status != MatchStatus.Disabled &&
                foundCompetition.Matches[i].Score > highestScore
            ) {
                highestScore = foundCompetition.Matches[i].Score;
                highestIndex = i;
            }
        }

        scoreIndices[returnCount++] = highestIndex;

        return scoreIndices;
    }

    // The player returns their submitted match. There's a time limit here.
    function SubmitMatch(
        bytes32 _competitionId,
        bytes calldata _dataPin,
        uint256 _score
    ) internal {
        // Get the match and make sure it's a match (Not default value)
        Storage storage ds = getStorage();
        bytes memory matchCheckId = createMatchCheckId(
            _competitionId,
            msg.sender
        );
        uint8[] storage playerMatches = ds.CompetitionMatchCheck[matchCheckId];
        uint8 currentMatchIndex = playerMatches[playerMatches.length - 1];

        Competition storage foundCompetition = _getCompetition(_competitionId);
        Match storage currentMatch = foundCompetition.Matches[
            currentMatchIndex
        ];

        //console.log("end time: %s", foundCompetition.EndTime);
        //console.log("block timestamp: %s", block.timestamp);
        require(
            block.timestamp < foundCompetition.EndTime,
            "COMPETITION_CLOSED"
        );

        // This means the last match has already been submitted
        require(
            currentMatch.Status == MatchStatus.Created,
            "MATCH_SUBMISSION_INVALID"
        );

        // This means the user took too long to submit the match
        require(
            currentMatch.EndTime <
                currentMatch.StartTime + foundCompetition.MatchDuration,
            "MATCH_EXPIRED"
        );

        currentMatch.Status = MatchStatus.Pending;
        currentMatch.DataPin = _dataPin;
        currentMatch.Score = _score;
        currentMatch.EndTime = block.timestamp;

        // Add data for tracking scores
        if (foundCompetition.PrizeType == PrizeType.WinnerTakeAll) {} else {
            revert("COMPETITION_TYPE_NOT_IMPLEMENTED");
        }

        // Update Player's last Match
        _getPlayerProfile(msg.sender).LastGameTimestamp = block.timestamp;

        // Check if there's another match
        if (foundCompetition.MatchesPerRound > currentMatchIndex) {
            _insertCompetitionPlayerMatch(
                _competitionId,
                _createDraftMatch(currentMatchIndex + 1)
            );
        }

        // Rank and ELO are not updated until the match is successfully scored
    }

    function _calculateLoyalty(
        address _player,
        int32 _reputation,
        uint16 _addMinutes
    ) internal view returns (uint64) {
        Storage storage ds = getStorage();
        uint16 currentMinutes = ds.DailyMinutesPlayed[_player];

        require(_addMinutes > 0 && _addMinutes < 24 * 60, "INVALID_PLAYTIME"); // At least one minute, and less minutes than in a day

        // Only loop up to length of loyalty calculation
        uint16 loopMinutes = _addMinutes;

        if (_addMinutes > ds.LoyaltyLookup.length) {
            loopMinutes = uint16(ds.LoyaltyLookup.length);
        }

        //console.log("_addMinutes: %s", uint(_addMinutes));
        //console.log("loopMinutes: %s", uint(loopMinutes));
        //console.log("LoyaltyLookup.length: %s", uint(LoyaltyLookup.length));

        uint64 loyaltyToAdd = 0;

        for (
            uint256 i = currentMinutes + 1;
            i <= currentMinutes + loopMinutes;
            i++
        ) {
            loyaltyToAdd += ds.LoyaltyLookup[i - 1]; // loyalty is 0-indexed, played minutes is 1-indexed
            //console.log("Accumulated loyalty: %s", uint(loyaltyToAdd));
        }

        // Now multiply the loyalty by the reputation bonus, which could bring it to zero
        loyaltyToAdd = uint64(
            _calculateUnsignedPercent(
                loyaltyToAdd,
                _playerRepLoyaltyMultiplier(_reputation)
            )
        );
        //console.log("Percentage applied loyalty: %s", uint(loyaltyToAdd));

        return loyaltyToAdd;
    }

    function _addPlayerLoyalty(address _player, uint16 _addMinutes) internal {
        PlayerProfile storage profile = _getPlayerProfile(_player);
        Storage storage ds = getStorage();

        //console.log("Loyalty before: %s", uint(profile.Loyalty));
        //console.log("Adding minutes: %s", uint(_addMinutes));
        //console.log("Reputation: %s", uint(int256(profile.Reputation)));
        profile.Loyalty += _calculateLoyalty(
            _player,
            profile.Reputation,
            _addMinutes
        );
        //console.log("Loyalty after: %s", uint(profile.Loyalty));
        ds.DailyMinutesPlayed[_player] += _addMinutes;
    }

    function _addPlayerReputation(address _player, int32 _add) internal {
        PlayerProfile storage profile = _getPlayerProfile(_player);
        profile.Reputation += _add;
    }

    function _calculateIdleReputationLoss(
        int32 _startingRep,
        uint16 _days
    ) internal pure returns (int32) {
        require(_days > 0, "INVALID_DURATION");

        // Get the sign, then do all work in positive.
        int8 signMultiplier = 1;

        if (_startingRep < 0) {
            signMultiplier = -1;
        }

        // If it's negative, turn it positive, widen it, then make it unsigned
        uint256 endingRep = uint256(int256(_startingRep * signMultiplier));

        for (uint16 i = 0; i < _days; i++) {
            endingRep = sqrt(endingRep) / 3;
        }

        return int32(int256(endingRep) * signMultiplier);
    }

    function ScoreCompetition(
        bytes32 _competitionId,
        uint96 _nodeNumber
    ) internal {
        Storage storage ds = getStorage();
        Competition storage foundCompetition = _getCompetition(_competitionId);

        // Since we're not checking that the node is online it could technically
        // score a match while "offline", but this should be OK
        bytes32 scoringNode = addressNumberToBytes32(
            AddressNumber({Address: msg.sender, Number: _nodeNumber})
        );

        // Competition can't be scored until the time has elapsed
        require(
            foundCompetition.EndTime < block.timestamp,
            "PENDING_COMPETITION"
        );

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

        for (uint256 i = 0; i < foundCompetition.Judges.length; i++) {
            if (foundCompetition.Judges[i] == scoringNode) {
                // Make the judge wait their turn in the queue to allow the first judge to score
                //console.log("Backup delay is: %s", i * nodeQueueBackupDelay);
                require(
                    block.timestamp >
                        foundCompetition.EndTime + i * ds.nodeQueueBackupDelay,
                    "EARLY_JUDGE"
                );
                isJudge = true;
                break;
            }
        }

        require(isJudge == true, "NOT_JUDGE");

        // Confirm there are disputes
        // This property doesn't indicate if disputes have been resolved
        if (foundCompetition.HasDisputes) {
            // Tried to short-circuit, now we need to iterate
            for (
                uint256 i = 0;
                i < ds.DisputedMatches[_competitionId].length;
                i++
            ) {
                uint256 matchIndex = ds.DisputedMatches[_competitionId][i];

                MatchDispute storage matchDispute = ds.MatchDisputes[
                    createMatchDisputeId(_competitionId, matchIndex)
                ];

                if (matchDispute.Status != MatchDisputeStatus.Created) {
                    // This dispute has already been resolved, on to the next one
                    continue;
                }

                MatchDisputeStatus disputeStatus = MatchDisputeCalculateStatus(
                    _competitionId,
                    matchIndex
                );

                // Auto-resolve expired ones if we can
                if (disputeStatus == MatchDisputeStatus.Expired) {
                    VoteType[] memory ignoreVotes = new VoteType[](0);
                    MatchDisputeResolve(
                        _competitionId,
                        matchIndex,
                        ignoreVotes
                    );
                } else if (
                    disputeStatus != MatchDisputeStatus.Innocent &&
                    disputeStatus != MatchDisputeStatus.Guilty
                ) {
                    // If it hasn't been closed, and we can't automatically resolve it then it's pending for now
                    revert("PENDING_DISPUTE");
                }
                // Else - match is already resolved
            }
        }

        if (foundCompetition.PrizeType == PrizeType.WinnerTakeAll) {
            // Get the top 1 winning matches
            uint256 topMatchIndex = _getSortedScores(_competitionId, 1)[0];
            Match storage topMatch = foundCompetition.Matches[topMatchIndex];

            PlayerProfile storage winner = _getPlayerProfile(
                addressToBytes32(topMatch.Player),
                true,
                false
            ); // If they got disabled but didn't cheat in this match, still award them

            winner.Rewards += foundCompetition.PrizePool;

            foundCompetition.Status = CompetitionStatus.Accepted;
        } else {
            revert("COMPETITION_TYPE_NOT_IMPLEMENTED");
        }

        PlayerProfile storage judgeProfile = _getPlayerProfile(msg.sender);

        // Use reputation multiplier
        uint256 judgeReward = _calculateUnsignedPercent(
            foundCompetition.NodeReward,
            _playerRepNodeEarning(judgeProfile.Reputation)
        );

        judgeProfile.Rewards += judgeReward;
        emit LogPlayerProfile(
            msg.sender,
            msg.sender,
            ChangeType.Updated,
            judgeProfile
        );

        // Things that apply to all users, like loyalty and reputation changes
        for (uint256 i = 0; i < foundCompetition.Players.length; i++) {
            address currentPlayer = foundCompetition.Players[i];
            // Check if the player's match is disabled (they cheated)
            bytes memory matchCheckId = createMatchCheckId(
                foundCompetition.CompetitionId,
                currentPlayer
            );
            // This checks for the first match because we're not checking the actual duration right now
            // If they cheat then all matches will be disabled, so checking the first one is enough
            Match storage checkMatch = foundCompetition.Matches[
                ds.CompetitionMatchCheck[matchCheckId][0]
            ];

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

                _addPlayerGameScore(
                    addressToBytes32(currentPlayer),
                    foundCompetition.GameDefinition,
                    checkMatch.Score
                );
                _addPlayerLoyalty(currentPlayer, minutesToAdd);
                _addPlayerReputation(
                    currentPlayer,
                    int32(ds.RepAdjustFinishMatch)
                );
                // TODO: Should we add an event here for player profile update?
            }
        }
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
    ) internal returns (address[] memory) {
        // Get N + 2 arbitrators, in case the accuser or accused come up in the list
        Storage storage ds = getStorage();
        uint256 itemsToReturn = 1 + ds.nodeQueueBackups; // Scoring node + backups
        uint256 itemsToFetch = itemsToReturn + 2; // allowance for accuser and accused

        address[] memory arbitrators = new address[](itemsToReturn);

        uint256 i = 0;
        while (arbitrators.length < itemsToReturn) {
            bytes32[] memory fetchedItems;
            (
                fetchedItems,
                ds.nodeQueueArbitrationIndex,
                ds.nodeQueueArbitrationCount
            ) = NodeQueueGetEntries(
                ds.nodeQueueArbitrationIndex,
                itemsToFetch,
                ds.nodeQueueArbitrationCount
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

    /// Dispute Functions
    // Match Dispute Functions
    function MatchDisputeCreate(
        bytes32 _competitionId,
        uint256 _matchIndex
    ) internal {
        Competition storage competition = _getCompetition(_competitionId);
        Storage storage ds = getStorage();

        Match storage disputedMatch = competition.Matches[_matchIndex];

        require(disputedMatch.Status == MatchStatus.Pending, "INVALID_MATCH");
        require(disputedMatch.Player != msg.sender, "INVALID_ACCUSE"); // They can't accuse themselves
        require(
            block.timestamp < disputedMatch.EndTime + ds.DisputeWindow,
            "INVALID_ACCUSE"
        ); // Can't accuse after the window

        // If not an operator, they must have played in the competition to accuse
        if (!ds.OURKADE.hasRole(ROLE_OPERATOR, msg.sender)) {
            uint8[] memory matchesPlayed = ds.CompetitionMatchCheck[
                createMatchCheckId(_competitionId, msg.sender)
            ];
            require(matchesPlayed.length > 0, "INVALID_ACCUSE");
        }

        bytes memory matchDisputeId = createMatchDisputeId(
            _competitionId,
            _matchIndex
        );
        MatchDispute storage matchDispute = ds.MatchDisputes[matchDisputeId];
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
        ds.DisputedMatches[_competitionId].push(_matchIndex);

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
        uint256 _matchIndex
    ) internal view returns (MatchDisputeStatus) {
        Storage storage ds = getStorage();
        Competition storage competition = _getCompetition(_competitionId);
        MatchDispute storage matchDispute = ds.MatchDisputes[
            createMatchDisputeId(_competitionId, _matchIndex)
        ];

        if (matchDispute.Status != MatchDisputeStatus.Created) {
            // If it's not still in Created status then it has resolved
            // so return the status which will be Guilty, Innocent, or Expired
            return matchDispute.Status;
        } else if (
            block.timestamp >=
            competition.EndTime + ds.DisputeDuration + ds.DisputeExpiry
        ) {
            return MatchDisputeStatus.Expired;
        } else if (
            block.timestamp >= competition.EndTime + ds.DisputeDuration
        ) {
            if (matchDispute.Votes.length >= ds.DisputeVotesRequired) {
                return MatchDisputeStatus.VotingClosed;
            } else {
                return MatchDisputeStatus.Expired; // Not enough votes, so it can be expired early
            }
        } else {
            // Not after the expiry or dispute ending, and disputes are only created after matches
            // This means we are in a time between match ending, and dispute vote closure
            if (matchDispute.Votes.length >= ds.DisputeVotesRequired) {
                return MatchDisputeStatus.EarlyResolve;
            } else {
                return MatchDisputeStatus.Pending;
            }
        }
    }

    function MatchDisputeSubmitVote(
        bytes32 _competitionId,
        uint256 _matchIndex,
        bytes32 _signature,
        bytes[] calldata _reveals
    ) internal {
        Storage storage ds = getStorage();
        MatchDispute storage matchDispute = ds.MatchDisputes[
            createMatchDisputeId(_competitionId, _matchIndex)
        ];

        require(matchDispute.MatchIndex != 0, "INVALID_DISPUTE");
        require(
            matchDispute.Status == MatchDisputeStatus.Created,
            "DISPUTE_CLOSED"
        );
        require(matchDispute.Voters[msg.sender] == false, "DUPLICATE_VOTE");
        // Don't allow accuser or accused to vote
        require(matchDispute.Accuser != msg.sender, "INVALID_VOTE");
        require(matchDispute.Accused != msg.sender, "INVALID_VOTE");
        // Not checking arbitrators because it's a small risk, and a lot of gas to loop through to check.

        // Get the profile of the accuser and use up a vote (or revert if they can't vote)
        PlayerProfile storage accuserProfile = _getPlayerProfile(msg.sender);
        _playerRepVote(msg.sender, accuserProfile.Reputation);

        MatchDisputeStatus disputeStatus = MatchDisputeCalculateStatus(
            _competitionId,
            _matchIndex
        );

        if (disputeStatus == MatchDisputeStatus.Expired) {
            // If it's expired then we can force it to close (and ignore this vote because it's late)
            // Resolve the dispute and exlcude this vote, it's late
            VoteType[] memory ignoreVotes = new VoteType[](0);
            MatchDisputeResolve(_competitionId, _matchIndex, ignoreVotes);
        } else if (
            disputeStatus == MatchDisputeStatus.Pending ||
            disputeStatus == MatchDisputeStatus.EarlyResolve
        ) {
            // Create the vote struct and add it to the list
            matchDispute.Votes.push(
                MatchDisputeVote(
                    addressToBytes32(msg.sender),
                    _signature,
                    _reveals,
                    VoteType.Hidden
                )
            );
            matchDispute.Voters[msg.sender] = true;
        } else if (disputeStatus == MatchDisputeStatus.VotingClosed) {
            revert("VOTING_CLOSED");
        }
    }

    function _calculatePenalty(
        uint256 _innocentVotes,
        uint256 _guiltyVotes,
        uint256 _guiltyCount
    ) internal view returns (uint16) {
        Storage storage ds = getStorage();
        uint8 guiltyVotePercent = uint8(
            (_guiltyVotes / (_guiltyVotes + _innocentVotes)) * 100
        );
        uint16 guiltyPenalty = 0;

        if (
            _innocentVotes > ds.DisputeVotesRequired &&
            _guiltyVotes > ds.DisputeVotesRequired
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

    // Upon dispute creation, determine the dispute admin
    // Admin cannot be the accuser, accused, or vote on the dispute
    // Voters sign a message with the Admin's internal key which includes: Competition, Address, Vote, + other hash?
    // When dispute is resolved, admin decrypts votes and tallys them
    // Voter can dispute decrypted value?
    //		Or by forcing admin to reveal secret (then we should use a different encrypting key which can be rerolled)

    function MatchDisputeResolve(
        bytes32 competitionId,
        uint256 _matchIndex,
        VoteType[] memory _revealedVotes
    ) internal {
        Storage storage ds = getStorage();
        bytes32 _competitionId = competitionId;
        bytes memory matchDisputeId = createMatchDisputeId(
            _competitionId,
            _matchIndex
        );
        MatchDispute storage matchDispute = ds.MatchDisputes[matchDisputeId];

        MatchDisputeStatus disputeStatus = MatchDisputeCalculateStatus(
            _competitionId,
            _matchIndex
        );

        // First check if it is already resolved or can be resolved.
        if (matchDispute.Status != MatchDisputeStatus.Created) {
            revert("INACTIVE_DISPUTE");
        } else if (disputeStatus == MatchDisputeStatus.Pending) {
            revert("PENDING_DISPUTE");
        }

        Competition storage competition = _getCompetition(_competitionId);

        // Now Check if the person can even resolve it.

        // A match can be marked as expired either because of time or not enough votes
        if (disputeStatus == MatchDisputeStatus.Expired) {
            // Anyone can resolve an expired dispute because it resets everything
            matchDispute.Status = MatchDisputeStatus.Expired;
        } else if (
            disputeStatus == MatchDisputeStatus.EarlyResolve ||
            disputeStatus == MatchDisputeStatus.VotingClosed
        ) {
            bool isArbitrator = false;

            for (uint256 i = 0; i < matchDispute.Arbitrators.length; i++) {
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
                uint256 totalVotes = matchDispute.Votes.length;

                // Update the votes
                uint256 innocentVotes = 0;
                uint256 guiltyVotes = 0;

                if (_revealedVotes.length != totalVotes) {
                    revert("INVALID_REVEAL");
                }

                // Iterate through the votes, revealing them and counting the total
                for (uint256 i = 0; i < _revealedVotes.length; i++) {
                    VoteType _currentVoteType = _revealedVotes[i];

                    MatchDisputeVote storage _currentVote = matchDispute.Votes[
                        i
                    ];
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

                PlayerProfile storage accused = _getPlayerProfile(
                    addressToBytes32(matchDispute.Accused),
                    true,
                    false
                ); // Track the cheating, even if they are disabled
                PlayerProfile storage accuser = _getPlayerProfile(
                    addressToBytes32(matchDispute.Accuser),
                    true,
                    false
                ); // Resolve dispute even if accuser is disabled

                assert(totalVotes >= ds.DisputeVotesRequired);

                // Decide the ruling
                VoteType disputeResult = guiltyVotes > innocentVotes
                    ? VoteType.Guilty
                    : VoteType.Innocent;

                if (disputeResult == VoteType.Guilty) {
                    /// Handle Accused
                    // Calculate penalty
                    uint16 guiltyPenalty = _calculatePenalty(
                        guiltyVotes,
                        innocentVotes,
                        accused.GuiltyCount
                    );

                    accused.Reputation -= int16(guiltyPenalty);
                    accused.GuiltyCount += 1;
                    accused.LastGuiltyTimestamp = block.timestamp;

                    if (
                        accused.Status != PlayerProfileStatus.Disabled &&
                        (accused.Reputation <= ds.RepInstantBan ||
                            accused.GuiltyCount >= ds.RepGuiltyLimit)
                    ) {
                        _removePlayerProfile(accused.PlayerProfileId);
                    }

                    // Disable all competition matches from the cheater
                    uint8[] storage disableIndices = ds.CompetitionMatchCheck[
                        createMatchCheckId(
                            _competitionId,
                            bytes32ToAddress(accused.PlayerProfileId)
                        )
                    ];

                    for (uint256 i = 0; i < disableIndices.length; i++) {
                        competition.Matches[i].Status = MatchStatus.Disabled;
                    }

                    /// Handle Accuser
                    accuser.Reputation += int32(ds.RepAdjustRightAccuse);

                    /// Resolve Dispute
                    matchDispute.Status = MatchDisputeStatus.Guilty;
                } else {
                    // Not Guilty

                    /// Handle Accused - Not Applicable

                    /// Handle Accuser
                    accuser.Reputation -= int32(ds.RepAdjustWrongAccuse);

                    /// Resolve Dispute
                    matchDispute.Status = MatchDisputeStatus.Innocent;
                }

                // Handle voters in one loop
                for (uint256 i = 0; i < matchDispute.Votes.length; i++) {
                    MatchDisputeVote storage _currentVote = matchDispute.Votes[
                        i
                    ];

                    PlayerProfile storage _currentVoter = _getPlayerProfile(
                        _currentVote.Voter
                    );

                    if (_currentVote.Vote == VoteType.Invalid) {
                        // Invalid vote
                        _currentVoter.Reputation = ds.RepInstantBan;
                        _removePlayerProfile(_currentVote.Voter);
                    } else if (_currentVote.Vote == disputeResult) {
                        // Correct vote
                        _currentVoter.Reputation -= int32(
                            ds.RepAdjustRightVote
                        );
                    } else {
                        // Incorrect vote
                        _currentVoter.Reputation -= int32(
                            ds.RepAdjustWrongVote
                        );
                    }
                }
            }
        }

        emit LogActionCompleted(
            msg.sender,
            AssignedAction.MatchDispute,
            matchDisputeId
        );
    }

    function NodeAssign(address _player, uint96 _count) internal {
        _createNodeInfo(_player, _count);
    }

    function NodeRemove(address _player, uint96 _count) internal {
        _removeNodeInfo(_player, _count);
    }

    function NodeQueueTierSet(
        uint256 _tier,
        uint64 _limit,
        uint256 _turns
    ) internal {
        Storage storage ds = getStorage();
        if (ds.nodeQueueTierCount == 0) {
            require(_tier == 0, "INVALID_NODE_TIER");
            ds.nodeQueueTierCount++;
        } else {
            require(_tier <= ds.nodeQueueTierCount, "INVALID_NODE_TIER"); // queue is 0-indexed, length is 1.

            if (_tier == ds.nodeQueueTierCount) {
                ds.nodeQueueTierCount++;
            }
        }

        ds.nodeQueueTierFees[_tier] = _limit;
        ds.nodeQueueTierTurns[_tier] = _turns;
    }

    function NodeQueueTierGet(
        uint256 _tier
    ) internal view returns (uint64, uint256) {
        Storage storage ds = getStorage();
        require(_tier < ds.nodeQueueTierCount, "INVALID_NODE_TIER"); // queue is 0-indexed, length is 1.
        return (ds.nodeQueueTierFees[_tier], ds.nodeQueueTierTurns[_tier]);
    }

    function NodeStatusOnline(uint96 _nodeNumber) internal {
        NodeInfo storage currentNode = _getNodeInfo(msg.sender, _nodeNumber);
        require(
            currentNode.Status != NodeInfoStatus.Active,
            "NODE_ALREADY_ACTIVE"
        );

        currentNode.Status = NodeInfoStatus.Active;

        // Join all the eligible queues
        for (uint256 i = 0; i < currentNode.LoyaltyLocked.length; i++) {
            _nodeQueueJoin(msg.sender, _nodeNumber);
        }
    }

    function _nodeStatusOffline(
        address _operator,
        uint96 _nodeNumber
    ) internal {
        NodeInfo storage currentNode = _getNodeInfo(_operator, _nodeNumber);
        require(currentNode.Status == NodeInfoStatus.Active, "NODE_NOT_ACTIVE");

        currentNode.Status = NodeInfoStatus.Inactive;

        // Exit the queue
        _nodeQueueLeave(msg.sender, _nodeNumber);
    }

    function NodeStatusOffline(uint96 _nodeNumber) internal {
        // Turn the node off which also leaves the queue
        _nodeStatusOffline(msg.sender, _nodeNumber);
    }

    // Automatically stake sequentially
    function NodeStakeQueueTier(uint96 _nodeNumber) internal {
        // Staking automatically joins the queue. Nodes don't get to pick which queues they're
        // in except by staking/unstaking. An online node will be in all queues they're eligible for
        _nodeStakeQueueTier(msg.sender, _nodeNumber);
    }

    // Automatically un-stake sequentially
    function NodeUnstakeQueueTier(uint96 _nodeNumber) internal {
        _nodeUnstakeQueueTier(msg.sender, _nodeNumber);
    }

    // Resets node queues and everyone needs to re-join
    function NodeQueueReset() internal {
        Storage storage ds = getStorage();
        delete ds.nodeQueueLookup; // TODO: Does this need to be re-initialized?

        // Empty out the people queued to leave
        for (uint256 i = 0; i < ds.nodeQueueLeaveList.length; i++) {
            delete ds.nodeQueueLeaveCheck[ds.nodeQueueLeaveList[i]];
        }

        delete ds.nodeQueueLeaveList;
        ds.nodeQueueScoringIndex = 0;
        ds.nodeQueueArbitrationIndex = 0;
        ds.nodeQueueScoringCount = 1;
        ds.nodeQueueArbitrationCount = 0;
    }

    ////
    //// Reputation (Clout) Functions
    ////

    // We don't need a function for "can join competition" because
    // competitions set their own join criteria, including Reputation.

    // Accepts a reputation and returns a node earning percentage
    function _playerRepNodeEarning(
        int32 _reputation
    ) internal pure returns (uint8) {
        if (_reputation > 32000) {
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
    function _playerRepLoyaltyMultiplier(
        int32 _reputation
    ) internal pure returns (uint8) {
        if (_reputation > 32000) {
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
        uint256 allowedFlags = 0;
        Storage storage ds = getStorage();

        if (_reputation > 32000) {
            allowedFlags = 4;
        } else if (_reputation > 20000) {
            allowedFlags = 3;
        } else if (_reputation > 4000) {
            allowedFlags = 2;
        }

        require(
            ds.playerDailyFlags[_player] < allowedFlags,
            "INSUFFICIENT_FLAGS"
        );

        ds.playerDailyFlags[_player]++;
    }

    function _playerRepVote(address _player, int32 _reputation) internal {
        uint256 allowedVotes = 0;
        Storage storage ds = getStorage();

        if (_reputation > 32000) {
            allowedVotes = 3;
        } else if (_reputation > 20000) {
            allowedVotes = 2;
        } else if (_reputation > 4000) {
            allowedVotes = 1;
        }

        require(
            ds.playerDailyVotes[_player] < allowedVotes,
            "INSUFFICIENT_VOTES"
        );

        ds.playerDailyVotes[_player]++;
    }

    function _playerRepBuyNode(int32 _reputation) internal view {
        Storage storage ds = getStorage();
        require(
            _reputation >= int32(uint32(ds.NodeBuyRepRequired)),
            "INSUFFICIENT_REPUTATION"
        );
    }

    // This function will be called every time and will
    // only perform updates when necessary.
    // This will allow the profile to be updated if it's
    // disabled, which means the caller needs to check that
    function _playerRepUpdate(PlayerProfile storage _profile) internal {
        address _playerAddress = bytes32ToAddress(_profile.PlayerProfileId);
        uint256 _latestDay = _getDay();
        Storage storage ds = getStorage();

        // First check if the rep has already been checked
        if (ds.playerLastCalcLookup[_playerAddress] == _latestDay) {
            // Rep has already been calculated
            return;
        }

        // TODO: Set player's last activity on necessary actions

        // Check if rep needs to be updated
        uint256 lastActive = ds.playerLastActivity[_playerAddress];
        uint16 inactiveDays = 0;
        if (lastActive < _latestDay - ds.seconds_in_day) {
            // Not active since before yesterday?
            inactiveDays = uint16(
                (_latestDay - lastActive) / ds.seconds_in_day
            );

            if (inactiveDays > ds.RepToZeroDays) {
                _profile.Reputation = 0;
            } else {
                _profile.Reputation += _calculateIdleReputationLoss(
                    _profile.Reputation,
                    inactiveDays
                );
            }
        }

        // Do other daily resets
        ds.playerDailyVotes[_playerAddress] = 0;
        ds.playerDailyFlags[_playerAddress] = 0;

        ds.playerLastCalcLookup[_playerAddress] = _latestDay;
    }

    function _getDay() internal returns (uint256) {
        Storage storage ds = getStorage();

        if ((block.timestamp / ds.seconds_in_day) > ds.currentDay) {
            ds.currentDay =
                block.timestamp -
                (block.timestamp % ds.seconds_in_day);
        }
        return ds.currentDay;
    }
}
