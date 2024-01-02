// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../storage/CTRStorage.sol";
import "../interface/IClaimTopicsRegistry.sol";

contract ClaimTopicsRegistry is IClaimTopicsRegistry, OwnableUpgradeable, CTRStorage {

    function init() external initializer {
        __Ownable_init();
    }

   
    function addClaimTopic(uint256 _claimTopic) external override onlyOwner {
        uint256 length = _claimTopics.length;
        require(length < 15, "cannot require more than 15 topics");
        for (uint256 i = 0; i < length; i++) {
            require(_claimTopics[i] != _claimTopic, "claimTopic already exists");
        }
        _claimTopics.push(_claimTopic);
        emit ClaimTopicAdded(_claimTopic);
    }

    /**
     *  @dev See {IClaimTopicsRegistry-removeClaimTopic}.
     */
    function removeClaimTopic(uint256 _claimTopic) external override onlyOwner {
        uint256 length = _claimTopics.length;
        for (uint256 i = 0; i < length; i++) {
            if (_claimTopics[i] == _claimTopic) {
                _claimTopics[i] = _claimTopics[length - 1];
                _claimTopics.pop();
                emit ClaimTopicRemoved(_claimTopic);
                break;
            }
        }
    }

    /**
     *  @dev See {IClaimTopicsRegistry-getClaimTopics}.
     */
    function getClaimTopics() external view override returns (uint256[] memory) {
        return _claimTopics;
    }
}
