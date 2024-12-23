// SPDX-License-Identifier:MIT
pragma solidity ^0.8.17;

import "../NodeInfo/regionNodeQueues.sol";

abstract contract Admin is regionNodeQueues {
    
    modifier isWallet {
		require(msg.sender == tx.origin, "WALLETS_ONLY");
		_;
	}

    // Only Admins
    function CreateGameDefinition(bytes32 _id, string calldata _name, bool _isMultiplayer) public onlyRole(ROLE_ADMIN) returns(bool) {
		require(bytes(_name).length != 0, "INVALID_GAME_NAME");
		require(bytes(_name).length <= 1024, "INVALID_GAME_NAME");

		_createGameDefinition(_id, GameDefinition(_id, _name, _isMultiplayer, GameDefinitionStatus.Created));

		return true;
	}

    // This will just prevent new competitions being created for this game
	function DisableGameDefinition(bytes32 _id) public onlyRole(ROLE_ADMIN) {
		GameDefinition storage gameDefinition = _getGameDefinition(_id);
		
		require(gameDefinition.Status == GameDefinitionStatus.Created, "GAME_NOT_ACTIVE");

		gameDefinition.Status = GameDefinitionStatus.Disabled;

		emit LogGame(msg.sender, _id, ChangeType.Disabled, gameDefinition);
	}

    function DepositTickets(address _target, uint _addTickets) public onlyRole(ROLE_ADMIN) {
		require(_addTickets > 0, "INVALID_TICKET_DEPOSIT");
		PlayerProfile storage profile = _getPlayerProfile(_target);
		profile.Tickets += _addTickets;
		emit LogPlayerProfile(msg.sender, _target, ChangeType.Updated, profile);
	}

    function AdminCreateProfile(address _target) public onlyRole(ROLE_ADMIN) {
		_createPlayerProfile(_target);
	}

    // Only admins can do this, and it should only be in exceptional cases
	// where guilty count was increased due to a mistake, or a
	// community-voted "amnesty" plan
	// No checks on it going negative, since Guilty Count is unsigned
	// will need to be called multiple times to reduce the amount to 0
	function AdminExcuseProfile(address _target) public onlyRole(ROLE_ADMIN) {
		PlayerProfile storage profile = _getPlayerProfile(_target);
		profile.GuiltyCount -=1;
		emit LogPlayerProfile(msg.sender, _target, ChangeType.Updated, profile);
	}

    // In case an account is completely banned they will need a full reset
	function AdminAbsolveProfile(address _target) public onlyRole(ROLE_ADMIN) {
		PlayerProfile storage profile = _getPlayerProfile(addressToBytes32(_target), true, false);
		profile.GuiltyCount = 0;
		profile.LastGuiltyTimestamp = 0;
		profile.Reputation = 0;
		profile.Status == PlayerProfileStatus.Created;
		emit LogPlayerProfile(msg.sender, _target, ChangeType.Enabled, profile);
	}

    function CreateProfile() public isWallet {
		_createPlayerProfile(msg.sender);
	}

}