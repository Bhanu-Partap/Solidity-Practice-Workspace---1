// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {ourkadelib} from "../library/ourkadelib.sol";
import "../Types.sol";

contract OurkadeCompetition {
    /* #endregion */

    // /* #region  Competitions */
    // function _createCompetition(bytes32 key, Competition memory newItem) private {
    // //Not implemented due to special logic
    // 	competitionLookup.insert(key);
    // 	competitions[key] = newItem;
    // 	emit LogCompetition(msg.sender, key, newItem);
    // }

    function createPlayerCompetitionId(
        address _player
    ) private returns (bytes32) {
        return ourkadelib.createPlayerCompetitionId(_player);
    }

    function _removeCompetition(bytes32 key) private {
        // This will fail automatically if the key doesn't exist
        ourkadelib._removeCompetition(key);
    }

    function checkCompetition(bytes32 key) public view returns (bool) {
        return ourkadelib.checkCompetition(key);
    }

    function _verifyCompetition(bytes32 key) private view {
        ourkadelib._verifyCompetition(key);
    }

    function _getCompetition(
        bytes32 key
    ) internal view returns (Competition storage) {
        // We have to verify, because array lookup won't fail if it's null
        return ourkadelib._getCompetition(key);
    }

    function getCompetition(
        bytes32 key
    ) public view returns (Competition memory) {
        return ourkadelib.getCompetition(key);
    }

    function getCompetitionCount() public view returns (uint256 count) {
        return ourkadelib.getCompetitionCount();
    }

    function getCompetitionAtIndex(
        uint256 index
    ) public view returns (bytes32 key) {
        return ourkadelib.getCompetitionAtIndex(index);
    }

    function CreateCompetition(bytes calldata _competitionParamBytes) public {
        ourkadelib.CreateCompetition(_competitionParamBytes);
    }

    function ArchiveCompetition(
        bytes32 _competitionId,
        bytes calldata _pinId
    ) private {
        ourkadelib.ArchiveCompetition(_competitionId, _pinId);
    }

    function _cancelCompetition(bytes32 _competitionId) private {
        ourkadelib._cancelCompetition(_competitionId);
    }

    function CancelCompetition(bytes32 _competitionId) public {
        ourkadelib.CancelCompetition(_competitionId);
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
    ) private returns (address[] memory) {
        return ourkadelib._getMatchDisputeArbitrators(_accuser, _accused);
    }

    function MatchDisputeCreate(
        bytes32 _competitionId,
        uint256 _matchIndex
    ) public {
        ourkadelib.MatchDisputeCreate(_competitionId, _matchIndex);
    }
}
