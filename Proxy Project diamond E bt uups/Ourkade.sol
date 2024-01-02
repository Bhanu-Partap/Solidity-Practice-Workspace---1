// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./Helpers/admin.sol";
import "./Competition/ourkadeScoring.sol";


contract OurkadeLogic is Admin, ourkadeScoring{
	// bytes32 public constant ROLE_ADMIN = keccak256("OURKADE_ADMIN");
	// bytes32 public constant ROLE_OPERATOR = keccak256("OURKADE_OPERATOR");

	constructor () {
		_grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_setRoleAdmin(ROLE_ADMIN, DEFAULT_ADMIN_ROLE);
		_setRoleAdmin(ROLE_OPERATOR, ROLE_ADMIN);
	}

		
	/// Internal Functions
	// Returns 12 bits, so the nonce address + nonce fit in 32 bytes

	// function NextCompetitionNonce(address _sender) private returns(uint96) {
	// 	PlayerProfile storage currentPlayer = _getPlayerProfile(_sender);
	// 	currentPlayer.CompetitionNonce += 1;
	// 	return currentPlayer.CompetitionNonce - 1;
	// }

	function _checkCompetitionPlayerHasNoMatches(bytes32 _competitionId, address _player) private view returns(bool) {
		return CompetitionMatchCheck[createMatchCheckId(_competitionId, _player)].length == 0;
	}

	function NodeAssign(address _player, uint96 _count) public onlyRole(ROLE_ADMIN) {
		_createNodeInfo(_player, _count);
	}

	function NodeRemove(address _player, uint96 _count) public onlyRole(ROLE_ADMIN) {
		_removeNodeInfo(_player, _count);
	}

	function NodeQueueTierSet(uint _tier, uint64 _limit, uint _turns) public onlyRole(ROLE_ADMIN) {
		if (nodeQueueTierCount == 0) {
			require(_tier == 0, "INVALID_NODE_TIER");
			nodeQueueTierCount++;
		} else {
			require(_tier <= nodeQueueTierCount,"INVALID_NODE_TIER"); // queue is 0-indexed, length is 1.

			if (_tier == nodeQueueTierCount) {
				nodeQueueTierCount++;
			}
		}

		nodeQueueTierFees[_tier] = _limit;
		nodeQueueTierTurns[_tier] = _turns;
	}

	function NodeStatusOnline(uint96 _nodeNumber) onlyRole(ROLE_OPERATOR) public {
		NodeInfo storage currentNode = _getNodeInfo(msg.sender, _nodeNumber);
		require(currentNode.Status != NodeInfoStatus.Active, "NODE_ALREADY_ACTIVE");

		currentNode.Status = NodeInfoStatus.Active;

		// Join all the eligible queues
		for(uint i = 0; i < currentNode.LoyaltyLocked.length; i++) {
			_nodeQueueJoin(msg.sender, _nodeNumber);
		}
	}


	function NodeStatusOffline(uint96 _nodeNumber) onlyRole(ROLE_OPERATOR) public {
		// Turn the node off which also leaves the queue
		_nodeStatusOffline(msg.sender, _nodeNumber);
	}

	// Automatically stake sequentially
	function NodeStakeQueueTier(uint96 _nodeNumber) onlyRole(ROLE_OPERATOR) public {
		// Staking automatically joins the queue. Nodes don't get to pick which queues they're
		// in except by staking/unstaking. An online node will be in all queues they're eligible for
		_nodeStakeQueueTier(msg.sender, _nodeNumber);
	}

	// Automatically un-stake sequentially
	function NodeUnstakeQueueTier(uint96 _nodeNumber) onlyRole(ROLE_OPERATOR) public {
		_nodeUnstakeQueueTier(msg.sender, _nodeNumber);		
	}

	// Resets node queues and everyone needs to re-join
	function NodeQueueReset() public onlyRole(ROLE_ADMIN) {
		delete nodeQueueLookup; // TODO: Does this need to be re-initialized?

		// Empty out the people queued to leave
		for (uint i = 0; i < nodeQueueLeaveList.length; i++) {
			delete nodeQueueLeaveCheck[nodeQueueLeaveList[i]];
		}

		delete nodeQueueLeaveList;
		nodeQueueScoringIndex = 0;
		nodeQueueArbitrationIndex = 0;
		nodeQueueScoringCount = 1;
		nodeQueueArbitrationCount = 0;
	}

	

}