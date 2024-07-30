// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./Enums.sol";
import "./library/HitchensUnorderedKeySet.sol";

// Struct designed to store address + data and fit within bytes32
// Address comes second to keep the address right-aligned the same
// way it is when stored as just an address in bytes32
struct AddressData {
    bytes12 Data;
    address Address;
}

// Struct designed to store address + number and fit within bytes32
// Address comes second to keep the address right-aligned the same
// way it is when stored as just an address in bytes32
struct AddressNumber {
    uint96 Number;
    address Address;
}

struct CompetitionParams {
    bytes32 GameDefinition;
    bool EligibleByTicket; // Must provide a ticket signed by competition creator
    uint64 EligibleLoyalty; // 8 Decimal places, must be above this value
    int16 EligibleReputation; // 2 Decimal places, must be above this value
    uint8 EligibleRankMinimum;
    uint8 EligibleRankMaximum;
    uint16 EligibleEloMinimum;
    uint16 EligibleEloMaximum;
    CurrencyType CurrencyType;
    PrizeType PrizeType;
    uint PrizePool;
    uint NodeReward;
    uint EntryFee;
    uint MinimumPlayers;
    uint MaximumPlayers;
    uint8 MatchesPerRound;
    uint MatchDuration; // In Seconds
}

struct Competition {
    bytes32 CompetitionId;
    bytes32 GameDefinition;
    bool EligibleByTicket; // Must provide a ticket signed by competition creator
    uint64 EligibleLoyalty; // 8 Decimal places, must be above this value
    int16 EligibleReputation; // 2 Decimal places, must be above this value
    uint8 EligibleRankMinimum; // This will control the scoring queue it's in
    uint8 EligibleRankMaximum;
    uint16 EligibleEloMinimum;
    uint16 EligibleEloMaximum;
    CurrencyType CurrencyType;
    PrizeType PrizeType;
    uint PrizePool;
    uint NodeReward;
    uint EntryFee;
    uint MinimumPlayers;
    uint MaximumPlayers;
    address[] Players;
    Match[] Matches;
    uint[] MatchScoreData;
    uint EndTime;
    uint8 MatchesPerRound;
    uint MatchDuration; // In Seconds
    bool HasDisputes;
    bytes DataPin; // May want to improve this // ~34 bytes
    bytes32[] Judges;
    CompetitionStatus Status;
}

struct CompetitionTicket{
    bytes32 CompetitionId;
    bytes32 PlayerId;
}

struct Match {
    bytes DataPin; // May want to improve this // ~34 bytes
    uint8 Round; // 1 byte
    address Player; // 20 bytes
    uint Score; // 32 bytes
    MatchStatus Status; // 8 bytes
    uint StartTime;
    uint EndTime;
}

struct MatchDispute {
    uint MatchIndex;
    address Accused;
    address Accuser;
    MatchDisputeStatus Status;
    address[] Arbitrators;
    MatchDisputeVote[] Votes;
    mapping(address => bool) Voters;
}

struct MatchDisputeVote {
    bytes32 Voter;
    bytes32 Signature;
    bytes[] Reveals;
    VoteType Vote;
}

struct GameDefinition {
    bytes32 GameDefinitionId;
    string Name;
    bool IsMultiplayer;
    GameDefinitionStatus Status;
}

struct PlayerProfile {
    bytes32 PlayerProfileId; // Address
    uint Tickets;
    uint Rewards;
    uint64 Loyalty; // 8 Decimal places
    int32 Reputation; // 2 Decimal places
    uint96 CompetitionNonce;
    uint LastGameTimestamp;
    uint GuiltyCount;
    uint LastGuiltyTimestamp;
    uint96 NodeCount; // Number of nodes owned by this player, can be used to look up NodeInfo
    PlayerProfileStatus Status;
}

struct NodeInfo {
    address PlayerProfileId; // Address
    uint96 NodeId; // Node Instance
    uint64[] LoyaltyLocked; // 8 Decimal Places - Index is the queue joined with the loyalty
    NodeInfoStatus Status;
}

// Both bounds should be inclusive
struct Range {
    int LowerBound;
    int UpperBound;
}
