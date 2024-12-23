// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

abstract contract configuration is AccessControlUpgradeable{
    bytes32 public constant ROLE_ADMIN = keccak256("OURKADE_ADMIN");
	bytes32 public constant ROLE_OPERATOR = keccak256("OURKADE_OPERATOR");
    // Configuration
	uint8 internal CompetitionSlash = 25; // Default percent to slash for failed competition
    // Reputation variables
	uint8 internal DisputeVotesRequired = 50;
    uint32 internal DisputeDuration = 2*24*60*60; // How long (in seconds) after creation until dispute can be closed. Default: 2 days
    uint16 internal RepAdjustRightAccuse = 800; // Reputation gain for accusing correctly
    uint16 internal RepAdjustWrongAccuse = 0; // Reputation loss for accusing incorrectly
    uint32 internal MatchTimeLimit =  7*24*60*60; // default is 7 days
    uint64[] internal LoyaltyLookup; // Index: minute of play, Value: Reward for play

     // Configuration Functions
    function SetCompetitionSlash(uint8 _value) public onlyRole(ROLE_ADMIN) {
		require(_value <= 100, "INVALID_COMPETITION_SLASH");
		CompetitionSlash = _value;
	}

    function SetDisputeDuration(uint32 _value) public onlyRole(ROLE_ADMIN) {
		DisputeDuration = _value;
	}

    function SetDisputeVotesRequired(uint8 _value) public onlyRole(ROLE_ADMIN) {
		DisputeVotesRequired = _value;
	}

    function SetRepAdjustRightAccuse(uint16 _value) public onlyRole(ROLE_ADMIN) {
		RepAdjustRightAccuse = _value;
	}

    function SetRepAdjustWrongAccuse(uint16 _value) public onlyRole(ROLE_ADMIN) {
		RepAdjustWrongAccuse = _value;
	}

    function SetMatchTimeLimit(uint32 _value) public onlyRole(ROLE_ADMIN) {
		MatchTimeLimit = _value;
	}

    function SetLoyaltyLookup(uint64[] calldata _value) public onlyRole(ROLE_ADMIN) {
		LoyaltyLookup = _value;
	}

    // Access Control functions
    function IsAccessAdmin(address _address) public view returns (bool) {
		return hasRole(DEFAULT_ADMIN_ROLE, _address);
	}

	function IsOurkadeAdmin(address _address) public view returns (bool) {
		return hasRole(ROLE_ADMIN, _address);
	}

	function IsOurkadeOperator(address _address) public view returns (bool) {
		return hasRole(ROLE_OPERATOR, _address);
	}

	function AddOurkadeAdmin(address _address) public onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
		grantRole(ROLE_ADMIN, _address);
		return true;
	}

	function RemoveOurkadeAdmin(address _address) public onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
		revokeRole(ROLE_ADMIN, _address);
		return true;
	}

	function AddOurkadeOperator(address _address) public onlyRole(ROLE_ADMIN) returns (bool) {
		grantRole(ROLE_OPERATOR, _address);
		return true;
	}

	function RemoveOurkadeOperator(address _address) public onlyRole(ROLE_ADMIN) returns (bool) {
		revokeRole(ROLE_OPERATOR, _address);
		return true;
	}
    
}