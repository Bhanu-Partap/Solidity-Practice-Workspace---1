// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

enum ChangeType {
	// CRUD Standard
	Created,
	Updated,
	Removed,
	// Status Standard
	Disabled,
	Enabled
}

enum QueueChangeType {
    Added,
    Removed,
    Rebuilt
}

enum AssignedAction {
    CompetitionScore,
    MatchDispute
}

enum PrizeType {
    WinnerTakeAll,
    Top3,
    RankCurve,
    ScoreProportional,
    Fixed
}

enum CurrencyType {
    Ticket,
    Honor,
    Reward
}

enum EligibleType {
    Open,
    ELO,
    Reputation,
    AllowList,
    Invite
}

enum VoteType {
    Hidden,
    Guilty,
    Innocent,
    Invalid
}

// These statuses are unique enums to avoid
// referencing statuses that are not applicable
// to different object types, and to avoid
// doing an incorrect comparison between them

enum PlayerProfileStatus {
    Created,
    Disabled
}

enum CompetitionStatus {
    Created,
    Accepted,
    Disabled
}

enum GameDefinitionStatus {
    Created,
    Disabled
}

enum MatchStatus {
    Created,
    Pending,
    Disabled
}

enum NodeInfoStatus {
    Inactive,
    Active
}

enum MatchDisputeStatus {
    Created,
    Pending, // Calculated
    // the two resolve statuses are not duplicates because
    // votes can still be registered during EarlyResolve
    EarlyResolve, // Calculated
    VotingClosed, // Calculated
    Expired, // Calculated and then saved
    Innocent,
    Guilty
}

enum ReputationRank {
    Banned,
    Negative2,
    Negative1,
    Neutral,
    Positive1,
    Positive2,
    Positive3,
    Positive4
}
