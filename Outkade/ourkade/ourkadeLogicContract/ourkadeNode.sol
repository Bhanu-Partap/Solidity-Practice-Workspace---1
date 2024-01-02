// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {ourkadelib} from "../library/ourkadelib.sol";
import "../Types.sol";

contract OurkadeNode {
    /* #endregion */

    /* #region NodeInfo */

    function _createNodeInfo(address _player, uint96 _count) private {
        ourkadelib._createNodeInfo(_player, _count);
    }

    function _nodeStakeQueueTier(address _player, uint96 _nodeNumber) private {
        ourkadelib._nodeStakeQueueTier(_player, _nodeNumber);
    }

    function _nodeUnstakeQueueTier(
        address _player,
        uint96 _nodeNumber
    ) private {
        ourkadelib._nodeUnstakeQueueTier(_player, _nodeNumber);
    }

    function _removeNodeInfo(address _player, uint96 _count) private {
        ourkadelib._removeNodeInfo(_player, _count);
    }

    function checkNodeInfo(
        address key,
        uint96 nodeId
    ) public view returns (bool) {
        return ourkadelib.checkNodeInfo(key, nodeId);
    }

    function _verifyNodeInfo(address key, uint96 nodeId) private view {
        ourkadelib._verifyNodeInfo(key, nodeId);
    }

    function _getNodeInfo(
        address key,
        uint96 nodeId
    ) internal view returns (NodeInfo storage) {
        return ourkadelib._getNodeInfo(key, nodeId);
    }

    function GetNodeInfoCount() public view returns (uint256 count) {
        return ourkadelib.GetNodeInfoCount();
    }

    function GetNodeIdAtIndex(uint256 index) public view returns (bytes32 key) {
        return ourkadelib.GetNodeIdAtIndex(index);
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
    ) private view returns (uint256) {
        // The turns per tier is stored as a total number
        // so we just need to find out which tier the node is staked to
        // which is the length of their locked loyalty

        return ourkadelib._nodeQueueTurns(_operator, _nodeNumber);
    }

  

    // This actually just flags the node for removal upon next compact
    // The function to get entries will ignore offline nodes

    function _nodeQueueLeave(address key, uint96 nodeId) private {
        ourkadelib._nodeQueueLeave(key, nodeId);
    }

    function _nodeQueueCompact() private {
        ourkadelib._nodeQueueCompact();
    }

    // DEBUG function. Should be removed later
    // Returns the count of IDs from the queue
    function GetNodeQueueIds(
        uint256 _count
    ) public view returns (bytes32[] memory) {
        return ourkadelib.GetNodeQueueIds(_count);
    }

    // It's the responsibility of the caller to track where to start from
    // Caller is responsible to update index and remaining turns if necessary
    // Allowing this to be external for testing and transparency
    // Returns the list of entries, next index, remaining turns for next index

    function NodeQueueGetEntries(
        uint256 start,
        uint256 count,
        uint256 initialRemainingTurns
    ) public returns (bytes32[] memory, uint256, uint256) {
        return
            ourkadelib.NodeQueueGetEntries(start, count, initialRemainingTurns);
    }

    function NodeQueueGetLength() public view returns (uint256) {
        return ourkadelib.NodeQueueGetLength();
    }

    function GetNodeInfo(
        address key,
        uint96 nodeId
    ) public view returns (NodeInfo memory) {
        return ourkadelib.GetNodeInfo(key, nodeId);
    }

    function NodeQueueTierGet(
        uint256 _tier
    ) public view returns (uint64, uint256) {
        return ourkadelib.NodeQueueTierGet(_tier);
    }

    function _nodeStatusOffline(address _operator, uint96 _nodeNumber) private {
        ourkadelib._nodeStatusOffline(_operator, _nodeNumber);
    }
}
