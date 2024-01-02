// SPDX-License-Identifier:MIT
pragma solidity ^0.8.17;

import "../Profile/players.sol";

abstract contract regionNodeInfo is regionProfile{

   
    uint32 NodeBuyRepRequired = 0; // Reputation required to buy a node
    uint32 nodeQueueTierCount; // Number of node tiers in existence. Could be optimized.
    mapping(uint => uint64) nodeQueueTierFees; // Fee to join each queue. Index is queue number.
    mapping(uint => uint) nodeQueueTierTurns; // The number of turns granted by each tier;

    //// Node Info Storage
	HitchensUnorderedKeySetLib.Set internal nodeInfoLookup;
	mapping(bytes32 => NodeInfo) internal nodeInfos;
    using HitchensUnorderedKeySetLib for HitchensUnorderedKeySetLib.Set;

    // events 
    event LogNodeInfo(address indexed sender, bytes32 indexed key, ChangeType indexed change, NodeInfo info);

    /* #region NodeInfo */
    function _createNodeInfo(address _player, uint96 _count) internal {
		uint32 NodeBuyRepFloor = 10000; // Reputation granted when getting a node.
		require(_count > 0, "NODE_INVALID_QUANTITY");
		
		PlayerProfile storage targetPlayer = _getPlayerProfile(_player);

		// Check if the player has enough reputation to buy a node
		// This should really be stopped on the front-end until it's full web3
		// This is just a double check
		_playerRepBuyNode(targetPlayer.Reputation);

		require(_count + targetPlayer.NodeCount < type(uint96).max, "NODE_INVALID_QUANTITY");

		for (uint96 i = 1; i <= _count; i++) {
			bytes32 newId = addressNumberToBytes32(AddressNumber({Address: _player, Number: ++targetPlayer.NodeCount}));
			nodeInfoLookup.insert(newId);
			NodeInfo storage newItem = nodeInfos[newId];

			newItem.PlayerProfileId = _player;
			newItem.NodeId = targetPlayer.NodeCount;
			newItem.Status = NodeInfoStatus.Inactive;

			emit LogNodeInfo(msg.sender, newId, ChangeType.Created, newItem);
		}

		// Update the player's rep to the floor for node owners
		//console.log("Reputation before: %s", Strings.toString(uint(int256(targetPlayer.Reputation))));
		//console.log("Node buy rep floor: %s", Strings.toString(uint(NodeBuyRepFloor)));
		if (targetPlayer.Reputation < int32(NodeBuyRepFloor)) {
			targetPlayer.Reputation = int32(NodeBuyRepFloor);
			//console.log("Reputation after: %s", Strings.toString(uint(int256(targetPlayer.Reputation))));
		}

		emit LogPlayerProfile(msg.sender, _player, ChangeType.Updated, targetPlayer);		
	}

    function _nodeStakeQueueTier(address _player, uint96 _nodeNumber) internal {
		PlayerProfile storage currentPlayer = _getPlayerProfile(_player);
		NodeInfo storage currentNode = _getNodeInfo(_player, _nodeNumber);

		uint nextTier = currentNode.LoyaltyLocked.length;
		uint64 tierFee;
		(tierFee, ) = NodeQueueTierGet(nextTier);

		require(currentPlayer.Loyalty >= tierFee, "INSUFFICIENT_LOYALTY");

		currentPlayer.Loyalty -= tierFee;

		currentNode.LoyaltyLocked.push(tierFee);

		// No other action is needed. The function to get items from the queue
		// checks how many turns a node should get. If the player stakes before
		// it is their turn then they get the extra turn this cycle
		// If they stake during or after their turn, it will be applied next cycle

		emit LogPlayerProfile(msg.sender, _player, ChangeType.Updated, currentPlayer);
	}



    function checkNodeInfo(address key, uint96 nodeId) public view returns(bool) {
		bytes32 checkId = addressNumberToBytes32(AddressNumber({Address: key, Number: nodeId}));
		return nodeInfoLookup.exists(checkId);
	}

	function _verifyNodeInfo(address key, uint96 nodeId) internal view {
		require(checkNodeInfo(key, nodeId) == true, "NODE_INFO_DOES_NOT_EXIST");
	}

	function _getNodeInfo(address key, uint96 nodeId) view internal returns(NodeInfo storage) {
		bytes32 getId = addressNumberToBytes32(AddressNumber({Address: key, Number: nodeId}));
		// We have to verify, because array lookup won't fail if it's null
		_verifyNodeInfo(key, nodeId);
        NodeInfo storage item = nodeInfos[getId];
		
        return(item);
    }

    function GetNodeInfo(address key, uint96 nodeId) public view returns(NodeInfo memory) {
		return _getNodeInfo(key, nodeId);
    }

	function GetNodeInfoCount() public view returns(uint count) {
        return nodeInfoLookup.count();
    }

    function GetNodeIdAtIndex(uint index) public view returns(bytes32 key) {
        return nodeInfoLookup.keyAtIndex(index);
    }
	/* #endregion */

    function _playerRepBuyNode(int32 _reputation) view internal {
		require(_reputation >= int32(uint32(NodeBuyRepRequired)), "INSUFFICIENT_REPUTATION");
	}

    function NodeQueueTierGet(uint _tier) view public returns(uint64, uint) {
		require(_tier < nodeQueueTierCount,"INVALID_NODE_TIER"); // queue is 0-indexed, length is 1.
		return (nodeQueueTierFees[_tier], nodeQueueTierTurns[_tier]);
	}


}