// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import "@onchain-id/solidity/contracts/interface/IClaimIssuer.sol";

interface ITrustedIssuersRegistry {
    event TrustedIssuerAdded(
        IClaimIssuer indexed trustedIssuer,
        uint256[] claimTopics
    );

    event TrustedIssuerRemoved(IClaimIssuer indexed trustedIssuer);

    event ClaimTopicsUpdated(
        IClaimIssuer indexed trustedIssuer,
        uint256[] claimTopics
    );

    function addTrustedIssuer(
        IClaimIssuer _trustedIssuer,
        uint256[] calldata _claimTopics
    ) external;

    function removeTrustedIssuer(IClaimIssuer _trustedIssuer) external;

    function updateIssuerClaimTopics(
        IClaimIssuer _trustedIssuer,
        uint256[] calldata _claimTopics
    ) external;

    function getTrustedIssuers() external view returns (IClaimIssuer[] memory);

    function getTrustedIssuersForClaimTopic(uint256 claimTopic)
        external
        view
        returns (IClaimIssuer[] memory);

    function isTrustedIssuer(address _issuer) external view returns (bool);

    function getTrustedIssuerClaimTopics(IClaimIssuer _trustedIssuer)
        external
        view
        returns (uint256[] memory);

    function hasClaimTopic(address _issuer, uint256 _claimTopic)
        external
        view
        returns (bool);
}
