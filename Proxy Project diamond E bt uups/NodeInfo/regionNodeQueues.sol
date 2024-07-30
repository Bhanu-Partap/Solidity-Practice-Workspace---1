// SPDX-License-Identifier:MIT
pragma solidity ^0.8.17;

import "./regionNodeInfo.sol";

abstract contract regionNodeQueues is regionNodeInfo{

    //// Node Queue Storage
    using HitchensUnorderedKeySetLib for HitchensUnorderedKeySetLib.Set;
	HitchensUnorderedKeySetLib.Set internal nodeQueueLookup; // The set of nodes in the queue, in sequence
    bytes32[] nodeQueueLeaveList; // Use to track the nodes to be removed from queue on next compact
    mapping(bytes32 => bool) nodeQueueLeaveCheck; // Used to check if a node is queued to be removed

    // Node Queue Setting
    uint nodeQueueCompactLimit = 10;
    
    // Events
    event LogNodeQueueJoin(address indexed sender, bytes32 indexed key);
    event LogNodeQueueLeave(address indexed sender, bytes32 indexed key);

    /* #region Node Queues */
	// This "queue" is using a set to track unique items
	// and a position to track where it is in the "queue"
	// The operations are more restricted:
	// - join queue: a node joins the queue
	// - leave queue: a node leaves the queue
	// - get from queue: get x items starting at y position (wraps around)
	// - count queue: gets the count of items in the queue

    // This should return the number of turns a node gets in the queue based on its staking
	function _nodeQueueTurns(address _operator, uint96 _nodeNumber) view private returns (uint) {
		// The turns per tier is stored as a total number
		// so we just need to find out which tier the node is staked to
		// which is the length of their locked loyalty
		NodeInfo storage currentNode = _getNodeInfo(_operator, _nodeNumber);

		return nodeQueueTierTurns[currentNode.LoyaltyLocked.length - 1];
	}

    function _nodeQueueJoin(address key, uint96 nodeId) internal {
		bytes32 lookupId = addressNumberToBytes32(AddressNumber({Address: key, Number: nodeId}));
		_verifyNodeInfo(key, nodeId);

		// If they are queued to leave, just clear it so they stay in the queue
		if (nodeQueueLeaveCheck[lookupId] == true) {
			nodeQueueLeaveCheck[lookupId] = false;
		} else {
			// otherwise add them to the queue
			// Update Lookup
			// This should throw an error if it's already in the queue
			nodeQueueLookup.insert(lookupId);
		}

		// Emit the event in either case, because the leave event is emitted when
		// they request to leave
		emit LogNodeQueueJoin(msg.sender, lookupId);
	}

    // This actually just flags the node for removal upon next compact
	// The function to get entries will ignore offline nodes
	function _nodeQueueLeave(address key, uint96 nodeId) private {
		bytes32 lookupId = addressNumberToBytes32(AddressNumber({Address: key, Number: nodeId}));
		_verifyNodeInfo(key, nodeId);

		require(nodeQueueLeaveCheck[lookupId] == false, "ALREADY_QUEUED");

		nodeQueueLeaveCheck[lookupId] = true;
		nodeQueueLeaveList.push(lookupId);

        emit LogNodeQueueLeave(msg.sender, lookupId);
    }

    // This should not be used in practice, because if the queue is compacted before
	// it has completed a cycle then it will result in an uneven distribution of turns
	function NodeQueueCompact() public onlyRole(ROLE_ADMIN) {
		_nodeQueueCompact();
	}

    function _nodeQueueCompact() private {
		//console.log("_nodeQueueCompact called");
		uint queueLength = nodeQueueLeaveList.length;
		//console.log("leave queueLength: %s", queueLength);
		//console.log("node queueLength: %s", nodeQueueLookup.count());

		// Don't allow too many to be removed at a time to avoid running out of gas
		uint removeCount = queueLength > nodeQueueCompactLimit ? nodeQueueCompactLimit : queueLength; 
		//console.log("removeCount: %s", removeCount);

		for (uint i = 1; i <= removeCount; i++) {
			//console.log("in loop: %s", i);
			bytes32 removeId = nodeQueueLeaveList[queueLength-i];
			//console.log("removeId: %s", Strings.toHexString(uint256(removeId)));
			
			// Remove from queue
			nodeQueueLookup.remove(removeId);

			// Remove from compact lists
			nodeQueueLeaveCheck[removeId] = false;
			nodeQueueLeaveList.pop();
			//console.log("new leave queue length: %s", nodeQueueLeaveList.length);
			//console.log("new node queueLength: %s", nodeQueueLookup.count());
		}
	}

    // DEBUG function. Should be removed later
	// Returns the count of IDs from the queue
	function GetNodeQueueIds(uint _count) view public returns(bytes32[] memory) {
		
		bytes32[] memory returnItems = new bytes32[](_count);
		for (uint i = 0; i < _count; i++) {
			bytes32 currentId = nodeQueueLookup.keyAtIndex(i);
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
	function NodeQueueGetEntries(uint start, uint count, uint initialRemainingTurns) public returns(bytes32[] memory, uint, uint) {
		//console.log("NodeQueueGetEntries called");
		//console.log("start: %s", start);
		//console.log("count: %s", count);
		//console.log("initial remaining: %s", initialRemainingTurns);

		// for (uint i = 0; i < count; i++) {
		// //	console.log("node at index %s: %s", i, Strings.toHexString(uint(nodeQueueLookup.keyAtIndex(i))));
		// }

		uint queueLength = NodeQueueGetLength();
		// Can't get node entries from an empty queue
		require(queueLength > 0, "NODE_QUEUE_EMPTY");
		// Can't set start location outside of queue
		require(start < queueLength, "NODE_QUEUE_INVALID_START");
		
		uint currentIndex = start;
		uint currentCount = 0;

		bytes32[] memory returnItems = new bytes32[](count);

		uint currentRemainingTurns = initialRemainingTurns;

		bytes32 currentId = nodeQueueLookup.keyAtIndex(currentIndex);

		uint debugIteration = 0;
		while(currentCount < count) {
			debugIteration++;
			// if the node is not scheduled to leave then add it to the list
			// this saves us the gas of looking up the node info to check the status
			while (currentRemainingTurns > 0 && currentCount < count) {
				if (nodeQueueLeaveCheck[currentId] == true) {
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
			if(currentRemainingTurns == 0) {
				// Increment or wrap index
				if (currentIndex == queueLength - 1) {
					currentIndex = 0;

					// Compact the queue
					_nodeQueueCompact();
					queueLength = NodeQueueGetLength();
				} else {
					currentIndex++;
				}
				
				currentId = nodeQueueLookup.keyAtIndex(currentIndex);
				AddressNumber memory nextAddressNumber = bytes32ToAddressNumber(currentId);
				currentRemainingTurns = _nodeQueueTurns(nextAddressNumber.Address, nextAddressNumber.Number);
			}
		
		}

	
		//console.log("Returning index: %s", currentIndex);
		//console.log("Remaining turns: %s", currentRemainingTurns);
		// for (uint i = 0; i < returnItems.length; i++) {
		// //	console.log("returnItem at index %s: %s", Strings.toHexString(uint(returnItems[i])), i);
		// }

        return(returnItems, currentIndex, currentRemainingTurns);
    }

     function NodeQueueGetLength() public view returns(uint) {
		return nodeQueueLookup.count();
    }

    /* #endregion */

        function _nodeStatusOffline(address _operator, uint96 _nodeNumber) internal {
		NodeInfo storage currentNode = _getNodeInfo(_operator, _nodeNumber);
		require(currentNode.Status == NodeInfoStatus.Active, "NODE_NOT_ACTIVE");

		currentNode.Status = NodeInfoStatus.Inactive;

		// Exit the queue
		_nodeQueueLeave(msg.sender, _nodeNumber);
	}

        function _nodeUnstakeQueueTier(address _player, uint96 _nodeNumber) internal {
		PlayerProfile storage currentPlayer = _getPlayerProfile(_player);
		NodeInfo storage currentNode = _getNodeInfo(_player, _nodeNumber);

		uint leaveTier = currentNode.LoyaltyLocked.length - 1;

		currentPlayer.Loyalty += currentNode.LoyaltyLocked[leaveTier];

		currentNode.LoyaltyLocked.pop();

		// If they've left the last tier turn the node offline
		if (leaveTier == 0 && currentNode.Status == NodeInfoStatus.Active) {
			// Is this a gas issue to fetch the same data twice?
			_nodeStatusOffline(_player, _nodeNumber);
		}

		emit LogPlayerProfile(msg.sender, _player, ChangeType.Updated, currentPlayer);
	}


        function _removeNodeInfo(address _player, uint96 _count) internal {
		PlayerProfile storage targetPlayer = _getPlayerProfile(_player);

		require(_count <= targetPlayer.NodeCount, "NODE_INVALID");

		for (uint96 i = 0; i < _count; i++) {
			uint96 currentNodeNumber = targetPlayer.NodeCount - i; // Start by removing the last node
			bytes32 removeId = addressNumberToBytes32(AddressNumber({Address: _player, Number: currentNodeNumber}));

			NodeInfo storage removedItem = _getNodeInfo(_player, currentNodeNumber);

			for(uint x = 0; x < removedItem.LoyaltyLocked.length; x++) {
				_nodeUnstakeQueueTier(_player, currentNodeNumber);
			}

			if (removedItem.Status == NodeInfoStatus.Active) {
				_nodeStatusOffline(_player, currentNodeNumber);
			}			

			nodeInfoLookup.remove(removeId);
			delete nodeInfos[removeId];

			emit LogNodeInfo(msg.sender, removeId, ChangeType.Removed, removedItem);
		}
		
		targetPlayer.NodeCount -= _count;

		emit LogPlayerProfile(msg.sender, _player, ChangeType.Updated, targetPlayer);
		
	}

        // Region Profile Functions

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

         function _removePlayerProfile(address key) internal {
        _removePlayerProfile(addressToBytes32(key));
    }


    
}