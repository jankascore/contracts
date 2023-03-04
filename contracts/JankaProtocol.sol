// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

contract JankaProtocol is Ownable {
    /// The *minimum* duration of time during which an attested score may be challenged.
    /// @dev A static value is used here for simplicity, but a future version will make this dynamic.
    uint256 public constant CHALLENGE_WINDOW = 2 hours;

    /// An amount of at-risk Ether provided with a score attestation to thwart bad actors.
    /// @dev A static value is used here for simplicity, but a future version will make this dynamic.
    uint256 public constant REQUIRED_ATTESTATION_STAKE = 0.01 ether;

    struct Attestation {
        /// Has the user withdrawn their at-risk Ether?
        bool isStakeClaimed;

        /// The attester's Janka score, from an allowlisted scoring algorithm.
        /// @dev Range: 0-100 inclusive (integer).
        uint8 score;

        /// The time at which at-risk Ether is able to be withdrawn absent a challenge.
        /// @dev Using uint40 for gas savings (while keeping sufficient precision and future-proofing).
        uint40 finalizationTime;

        /// The scoring algorithm used (IPFS CID). Must be allowlisted.
        string algorithmCID;
    }

    mapping (address => Attestation) public attestations;

    /// An allowlist of known scoring algorithms (by IPFS CID string).
    /// @dev Using a mapping (vs array) for O(1) lookup by CID.
    mapping (string => bool) public supportedAlgorithms;

    /// An allowlist of verifiers which can be trusted to challenge bogus attestations.
    /// @dev Using a mapping (vs array) for O(1) lookup.
    mapping (address => bool) public allowlistedVerifiers;

    /// Allows an EOA to attest to a Janka score, subject to a verification challenge for `CHALLENGE_WINDOW`.
    /// @param _score An integer score ranging from 0-100 inclusive.
    /// @param _algorithmCID An IPFS CID indicating the algorithm used.
    /// @param _timestamp Unix timestamp at which this score was generated, for point-in-time verification.
    /// @return _finalizationTime Unix timestamp at which at-risk ether is able to be withdrawn.
    function attest(
        uint8 _score,
        string calldata _algorithmCID,
        uint256 _timestamp
    ) external payable returns (uint40 _finalizationTime) {
        /// Revert straight away if we know the score is bogus.
        if (_score > 100) revert InvalidScore(0, 100, _score);

        /// Ensure the provided IPFS CID is a known, allowlisted algorithm.
        if (!supportedAlgorithms[_algorithmCID]) revert InvalidAlgorithm();

        /// Don't allow the caller to start another attestation until the first is finished.
        /// @dev This was chosen for simplicity, future protocol upgrades may handle this.
        Attestation memory attestation = attestations[msg.sender];
        if (attestation.finalizationTime > 0 && !attestation.isStakeClaimed)
            revert AttestationOustanding();

        /// Verify that the caller has provided sufficient at-risk Ether.
        /// @dev Rather than deal with refunds (excess), we've opted to require an exact amount.
        if (msg.value != REQUIRED_ATTESTATION_STAKE)
            revert IncorrectStakeAmount(REQUIRED_ATTESTATION_STAKE, msg.value);

        uint40 finalizationTime = uint40(block.timestamp + CHALLENGE_WINDOW);
        attestations[msg.sender] = Attestation({
            score: _score,
            isStakeClaimed: false,
            algorithmCID: _algorithmCID,
            finalizationTime: finalizationTime
        });

        emit ScoreAttested(msg.sender, _score, _algorithmCID, _timestamp);
        return finalizationTime;
    }

    /// Allows an attestation to be challenged by a trusted verifier.
    /// @param _attester The EOA that submitted the original score attestation.
    /// @param _score The score that the challenger computed.
    /// @param _algorithmCID The scoring algorithm (IPFS CID) used for the challenge.
    /// @param _rewardRecipient An address to receive the challenge incentive.
    function challenge(
        address _attester,
        uint8 _score,
        string calldata _algorithmCID,
        address _rewardRecipient
    ) external {
        /// Only trusted verifiers can challenge attestations.
        if (!allowlistedVerifiers[msg.sender]) revert PermissionDenied();

        Attestation memory attestation = attestations[_attester];

        /// Verify that the attestation exists.
        /// @dev Using `finalizationTime` as a sentinel value.
        if (attestation.finalizationTime == 0)
            revert InvalidAttestationChallenge();

        /// An attestation can no longer be challenged after the at-risk ether has been withdrawn.
        if (attestation.isStakeClaimed) revert ChallengeDenied();

        /// Ensure that verification was performed using the same scoring algorithm version.
        if (keccak256(abi.encodePacked(attestation.algorithmCID))
            != keccak256(abi.encodePacked(_algorithmCID))) {
                revert InvalidAttestationChallenge();
        }

        /// Ensure that the challenger actually came up with a different score.
        if (attestation.score == _score) revert InvalidAttestationChallenge();

        /// Render the original attestation invalid.
        delete attestations[_attester];
        emit ScoreChallenged(
            _attester,
            msg.sender,
            attestation.score,
            _score,
            _algorithmCID
        );

        /// The fraudulent attestor forfeits their at-risk ether, having been successfully challenged.
        (bool isSuccess,) = payable(_rewardRecipient).call{value: REQUIRED_ATTESTATION_STAKE}("");
        require(isSuccess, "Incentive payment failed!");
    }

    /// Allows an EOA to reclaim staked Ether after `CHALLENGE_WINDOW` has passed.
    /// @dev `msg.sender` is used for simplicity, but future versions may allow a `to` withdraw address.
    function withdrawStake() external {
        Attestation memory attestation = attestations[msg.sender];

        /// Ensure the caller has an existing attestation.
        /// @dev Using `finalizationTime` as a sentinel value.
        if (attestation.finalizationTime == 0) revert InvalidWithdraw();

        /// Verify that this EOA hasn't already withdrawn.
        if (attestation.isStakeClaimed) revert InvalidWithdraw();

        /// Ensure the `CHALLENGE_WINDOW` has passed.
        if (block.timestamp < attestation.finalizationTime)
            revert WithdrawNotReady(attestation.finalizationTime - block.timestamp);

        attestations[msg.sender].isStakeClaimed = true;
        emit StakeWithdrawn(msg.sender, REQUIRED_ATTESTATION_STAKE);

        (bool isSuccess,) = payable(msg.sender).call{value: REQUIRED_ATTESTATION_STAKE}("");
        require(isSuccess, "Transmitting funds failed!");
    }

    /// Allows an administrator to add an IPFS CID to the allowlist for scoring.
    /// @param _algorithmCID An IPFS CID of a scoring algorithm permitted to be used.
    function allowAlgorithmCID(string calldata _algorithmCID) external onlyOwner {
        supportedAlgorithms[_algorithmCID] = true;
    }

    /// Allows an administrator to add a trusted verifier node to the allowlist for `challenge()`.
    /// @param _verifier The address of the verifier.
    function allowVerifier(address _verifier) external onlyOwner {
        allowlistedVerifiers[_verifier] = true;
    }

    event ScoreAttested(
        /// @dev Explicitly not indexed for now to allow for easier watching/consumption.
        address attester,
        uint8 score,
        string algorithmCID,
        uint256 timestamp
    );
    event ScoreChallenged(
        address indexed attester,
        address indexed challenger,
        uint8 scoreClaimed,
        uint8 scoreActual,
        string algorithmCID
    );
    event StakeWithdrawn(address indexed attester, uint256 amount);

    error AttestationOustanding();
    error ChallengeDenied();
    error IncorrectStakeAmount(uint256 amountExpected, uint256 amountProvided);
    error InvalidAlgorithm();
    error InvalidAttestationChallenge();
    error InvalidScore(uint8 min, uint8 max, uint8 provided);
    error InvalidWithdraw();
    error PermissionDenied();
    error WithdrawNotReady(uint256 timeRemaining);
}

