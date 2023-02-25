//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct SelfAttestation {
	address addr;
	string version;
	uint score;
	string arguments;
}

struct SavedSelfAttestation {
	address addr;
	string version;
	uint score;
	string arguments;
	uint savedAtBlockNo;
}

struct EscrowPosition {
	uint value;
	uint blockNo;
}

// Probably ownable
abstract contract Scores {
	mapping(address => SelfAttestation) scores;
	mapping(address => EscrowPosition) escrow;
	string[] versions;

	event SelfAttested(SelfAttestation attestation);

	function getVersions() virtual public view returns(string[] memory);
	function getLatestVersion() virtual public view returns(string memory);
	function addVersion(string calldata newVersion) public virtual; // only owner
	function selfAttest(SelfAttestation calldata attestation) public virtual payable; // emit SelfAttested
	function reportFraud(SelfAttestation calldata attestation) public virtual; //idk
}