// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

interface IClaimTopicsRegistry {
    event ClaimTopicAdded(uint256 indexed claimTopic);

    event ClaimTopicRemoved(uint256 indexed claimTopic);

    function addClaimTopic(uint256 _claimTopic) external;

    function removeClaimTopic(uint256 _claimTopic) external;

    function getClaimTopics() external view returns (uint256[] memory);
}
