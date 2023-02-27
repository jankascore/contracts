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
        bool isStakeClaimed;
        string algorithmCID;
        uint256 finalizationTime;
    }

    mapping (address => Attestation) public attestations;

    /// An allowlist of known scoring algorithms (by IPFS CID string).
    /// @dev Using a mapping (vs array) for quick lookup by CID.
    mapping (string => bool) public supportedAlgorithms;

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

        /// Ensure the provided IPFS CID is a known, allowlisted algorithm.
        if (!supportedAlgorithms[_algorithmCID]) revert InvalidAlgorithm();

        /// Don't allow the caller to start another attestation until the first is finished.
        /// @dev This was chosen for simplicity, future protocol upgrades may handle this.
        if (attestations[msg.sender].finalizationTime > 0)
            revert AttestationAlreadyExists();

        /// Verify that the caller has provided sufficient at-risk Ether.
        /// @dev Rather than deal with refunds (excess), we've opted to require an exact amount.
        if (msg.value != REQUIRED_ATTESTATION_STAKE)
            revert IncorrectStakeAmount(REQUIRED_ATTESTATION_STAKE, msg.value);

        uint256 finalizationTime = block.timestamp + CHALLENGE_WINDOW;
        attestations[msg.sender] = Attestation({
            score: _score,
            isStakeClaimed: false,
            algorithmCID: _algorithmCID,
            finalizationTime: finalizationTime
        });

        emit ScoreAttested(msg.sender, _score, _algorithmCID, finalizationTime);
        return finalizationTime;
    }

    /// Allows an EOA to reclaim staked Ether after `CHALLENGE_WINDOW` has passed.
    function withdrawStake() external {
        Attestation storage attestation = attestations[msg.sender];

        /// Ensure the caller has an existing attestation.
        /// @dev Using `finalizationTime` as a sentinel value.
        if (attestation.finalizationTime == 0) revert InvalidWithdraw();

        /// Verify that this EOA hasn't already withdrawn.
        if (attestation.isStakeClaimed) revert InvalidWithdraw();

        /// Ensure the `CHALLENGE_WINDOW` has passed.
        if (block.timestamp < attestation.finalizationTime)
            revert WithdrawNotReady(attestation.finalizationTime - block.timestamp);

        attestation.isStakeClaimed = true;
        emit StakeWithdrawn(msg.sender, REQUIRED_ATTESTATION_STAKE);

        (bool isSuccess,) = payable(msg.sender).call{value: REQUIRED_ATTESTATION_STAKE}("");
        require(isSuccess, "Transmitting funds failed!");
    }

    /// Allows an administrator to add an IPFS CID to the allowlist for scoring.
    /// @param _algorithmCID An IPFS CID of a scoring algorithm permitted to be used.
    function allowAlgorithmCID(
        string calldata _algorithmCID
    ) external onlyOwner {
        supportedAlgorithms[_algorithmCID] = true;
    }

    event ScoreAttested(
        address indexed attester,
        uint8 score,
        string algorithmCID,
        uint256 finalizationTime
    );

    event StakeWithdrawn(address indexed attester, uint256 amount);

    error AttestationAlreadyExists();
    error IncorrectStakeAmount(uint256 amountExpected, uint256 amountProvided);
    error InvalidAlgorithm();
    error InvalidScore(uint8 min, uint8 max, uint8 provided);
    error InvalidWithdraw();
    error WithdrawNotReady(uint256 timeRemaining);
}

