// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ourkadelib} from "../library/ourkadelib.sol";
import "../Types.sol";

contract OurkadeAdmin is Initializable {
    event RoleGranted(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );
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

    bytes32 constant ROLE_ADMIN = keccak256("OURKADE_ADMIN");
    bytes32 constant ROLE_OPERATOR = keccak256("OURKADE_OPERATOR");
    bytes32 constant DEFAULT_ADMIN_ROLE = bytes32(0);

    modifier onlyRole(bytes32 role) {
        ourkadelib.checkrole(role);
        _;
    }

    function init(address contractadmin) external initializer {
        constantdata();
        ourkadelib.DEFAULT_ADMIN(contractadmin);

        ourkadelib.setAdminRole(ROLE_ADMIN, DEFAULT_ADMIN_ROLE);
        ourkadelib.setAdminRole(ROLE_OPERATOR, ROLE_ADMIN);
    }

    // used for seeting all the default value
    function constantdata() internal {
        ourkadelib.constantdata();
    }

    /// Configuration Functions
    function SetCompetitionSlash(uint8 _value) public onlyRole(ROLE_ADMIN) {
        ourkadelib.SetCompetitionSlash(_value);
    }

    function SetDisputeDuration(uint256 _value) public onlyRole(ROLE_ADMIN) {
        ourkadelib.SetDisputeDuration(_value);
    }

    function SetDisputeVotesRequired(
        uint256 _value
    ) public onlyRole(ROLE_ADMIN) {
        ourkadelib.SetDisputeVotesRequired(_value);
    }

    function SetRepAdjustRightAccuse(
        uint32 _value
    ) public onlyRole(ROLE_ADMIN) {
        SetRepAdjustRightAccuse(_value);
    }

    function SetRepAdjustWrongAccuse(
        uint32 _value
    ) public onlyRole(ROLE_ADMIN) {
        ourkadelib.SetRepAdjustWrongAccuse(_value);
    }

    function SetMatchTimeLimit(uint256 _value) public onlyRole(ROLE_ADMIN) {
        ourkadelib.SetMatchTimeLimit(_value);
    }

    function SetLoyaltyLookup(
        uint64[] calldata _value
    ) public onlyRole(ROLE_ADMIN) {
        ourkadelib.SetLoyaltyLookup(_value);
    }

    function IsAccessAdmin(address _address) public view returns (bool) {
        return ourkadelib.IsAccessAdmin(_address);
    }

    function IsOurkadeAdmin(address _address) public view returns (bool) {
        return ourkadelib.IsOurkadeAdmin(_address);
    }

    function IsOurkadeOperator(address _address) public view returns (bool) {
        return ourkadelib.IsOurkadeOperator(_address);
    }

    function checkrole(bytes32 role) public view {
        ourkadelib.checkrole(role);
    }

    function AddOurkadeAdmin(
        address _address
    ) public onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        return ourkadelib.AddOurkadeAdmin(_address);
    }

    function RemoveOurkadeAdmin(
        address _address
    ) public onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        return ourkadelib.RemoveOurkadeAdmin(_address);
    }

    function AddOurkadeOperator(
        address _address
    ) public onlyRole(ROLE_ADMIN) returns (bool) {
        return ourkadelib.AddOurkadeOperator(_address);
    }

    function RemoveOurkadeOperator(
        address _address
    ) public onlyRole(ROLE_ADMIN) returns (bool) {
        return ourkadelib.RemoveOurkadeOperator(_address);
    }

    ///player

    // For now, only Ourkade admins can set player ranks
    function _setPlayerGameRank(
        bytes32 _gameDefinition,
        address _player,
        uint8 _rank
    ) private onlyRole(ROLE_ADMIN) {
        ourkadelib._setPlayerGameRank(_gameDefinition, _player, _rank);
    }

    function MatchDisputeSubmitVote(
        bytes32 _competitionId,
        uint256 _matchIndex,
        bytes32 _signature,
        bytes[] calldata _reveals
    ) public onlyRole(ROLE_OPERATOR) {
        ourkadelib.MatchDisputeSubmitVote(
            _competitionId,
            _matchIndex,
            _signature,
            _reveals
        );
    }

    ////game
    /* #endregion */

    // Only Admins

    function CreateGameDefinition(
        bytes32 _id,
        string calldata _name,
        bool _isMultiplayer
    ) public onlyRole(ROLE_ADMIN) returns (bool) {
        return ourkadelib.CreateGameDefinition(_id, _name, _isMultiplayer);
    }

    // This will just prevent new competitions being created for this game
    function DisableGameDefinition(bytes32 _id) public onlyRole(ROLE_ADMIN) {
        ourkadelib.DisableGameDefinition(_id);
    }

    // Function to allow bulk updating of player ranks because this will need
    // to be done by admins, likely from a service
    function SetPlayerGameRanks(
        bytes32[] calldata _gameDefinition,
        address[] calldata _player,
        uint8[] calldata _rank
    ) public onlyRole(ROLE_ADMIN) {
        ourkadelib.SetPlayerGameRanks(_gameDefinition, _player, _rank);
    }

    ///node

    // This should not be used in practice, because if the queue is compacted before
    // it has completed a cycle then it will result in an uneven distribution of turns
    function NodeQueueCompact() public onlyRole(ROLE_ADMIN) {
        ourkadelib.NodeQueueCompact();
    }

    function NodeAssign(
        address _player,
        uint96 _count
    ) public onlyRole(ROLE_ADMIN) {
        ourkadelib.NodeAssign(_player, _count);
    }

    function NodeRemove(
        address _player,
        uint96 _count
    ) public onlyRole(ROLE_ADMIN) {
        ourkadelib.NodeRemove(_player, _count);
    }

    function NodeStatusOnline(
        uint96 _nodeNumber
    ) public onlyRole(ROLE_OPERATOR) {
        ourkadelib.NodeStatusOnline(_nodeNumber);
    }

    function NodeQueueTierSet(
        uint256 _tier,
        uint64 _limit,
        uint256 _turns
    ) public onlyRole(ROLE_ADMIN) {
        ourkadelib.NodeQueueTierSet(_tier, _limit, _turns);
    }

    function NodeUnstakeQueueTier(
        uint96 _nodeNumber
    ) public onlyRole(ROLE_OPERATOR) {
        ourkadelib.NodeUnstakeQueueTier(_nodeNumber);
    }

    // Resets node queues and everyone needs to re-join
    function NodeQueueReset() public onlyRole(ROLE_ADMIN) {
        ourkadelib.NodeQueueReset();
    }

    function NodeStatusOffline(
        uint96 _nodeNumber
    ) public onlyRole(ROLE_OPERATOR) {
        // Turn the node off which also leaves the queue
        ourkadelib.NodeStatusOffline(_nodeNumber);
    }

    // Automatically stake sequentially
    function NodeStakeQueueTier(
        uint96 _nodeNumber
    ) public onlyRole(ROLE_OPERATOR) {
        // Staking automatically joins the queue. Nodes don't get to pick which queues they're
        // in except by staking/unstaking. An online node will be in all queues they're eligible for
        ourkadelib.NodeStakeQueueTier(_nodeNumber);
    }

    function DepositTickets(
        address _target,
        uint256 _addTickets
    ) public onlyRole(ROLE_ADMIN) {
        ourkadelib.DepositTickets(_target, _addTickets);
    }

    function AdminCreateProfile(address _target) public onlyRole(ROLE_ADMIN) {
        ourkadelib.AdminCreateProfile(_target);
    }

    // Only admins can do this, and it should only be in exceptional cases
    // where guilty count was increased due to a mistake, or a
    // community-voted "amnesty" plan
    // No checks on it going negative, since Guilty Count is unsigned
    // will need to be called multiple times to reduce the amount to 0
    function AdminExcuseProfile(address _target) public onlyRole(ROLE_ADMIN) {
        ourkadelib.AdminExcuseProfile(_target);
    }

    // In case an account is completely banned they will need a full reset
    function AdminAbsolveProfile(address _target) public onlyRole(ROLE_ADMIN) {
        ourkadelib.AdminAbsolveProfile(_target);
    }
}
