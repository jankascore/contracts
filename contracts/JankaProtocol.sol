// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

contract JankaProtocol is Ownable {
    /// A duration of time during which an attested score is able to be challenged.
    uint256 public constant CHALLENGE_WINDOW = 2 hours;

    /// An amount of at-risk Ether provided with a score attestation to thwart bad actors.
    uint256 public constant REQUIRED_ATTESTATION_STAKE = 0.01 ether;

    struct Attestation {
        uint8 score;
        string algorithmCID;
        uint256 finalizationTime;
    }

    mapping (address => Attestation) public attestations;

    /// Allows an EOA to attest to a score, subject to challenges for `CHALLENGE_WINDOW`.
    /// @param _score An integer score ranging from 0-100 inclusive.
    /// @param _algorithmCID An IPFS CID indicating the algorithm used.
    /// @return _finalizationTime The Unix timestamp at which the attestation is considered final (without challenge).
    function attest(
        uint8 _score,
        string calldata _algorithmCID
    ) external payable returns (uint256 _finalizationTime) {
        /// Revert straight away if we know the score is bogus.
        if (_score > 100) revert InvalidScore(0, 100, _score);

        /// Verify that the caller has provided sufficient at-risk Ether.
        if (msg.value < REQUIRED_ATTESTATION_STAKE)
            revert InsufficientStake(REQUIRED_ATTESTATION_STAKE, msg.value);

        // TODO: Decide how to handle an existing attestation in-flight.

        uint256 finalizationTime = block.timestamp + CHALLENGE_WINDOW;
        attestations[msg.sender] = Attestation({
            score: _score,
            algorithmCID: _algorithmCID,
            finalizationTime: finalizationTime
        });

        emit ScoreAttested(msg.sender, _score, _algorithmCID, finalizationTime);
        return finalizationTime;
    }

    event ScoreAttested(
        address indexed attester,
        uint8 score,
        string algorithmCID,
        uint256 finalizationTime
    );

    error InsufficientStake(uint256 amountExpected, uint256 amountProvided);
    error InvalidScore(uint8 min, uint8 max, uint8 provided);
}

