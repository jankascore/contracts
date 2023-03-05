# Janka Protocol

**TL;DR:** Janka Protocol performs on-chain credit scoring (the "Janka Score")!

Although the initial incarnation of the Janka Protocol was built in tandem with [a first-party dApp](https://janka.mckamyk.io/) for demonstration (ETHDenver '23) purposes, longer-term, Janka Protocol is intended to expose a set of on-chain credit scoring primitives for a plurality of applications to be built on top of! Future versions may also allow for pluggable/modular scoring functions for context-dependant use cases.

## Technical Explanation

In the current form, Janka Protocol uses an "optimistic" methodology: a user submits an on-chain attestation containing their Janka score, and off-chain Verifier processes monitor on-chain attestations looking for fraud (and subsequently issuing a challenge when found).

At a high level, it works as follows:

- The user navigates to [a dApp](https://janka.mckamyk.io/).
- The dApp has a pointer (IPFS CID) to the latest Janka scoring algorithm and loads it from decentralized storage on IPFS.
- The dApp then, using data obtained from The Graph, computes the user's Janka score based on on-chain activity.
- The user then invokes the Janka Protocols `attest()` contract function, providing the computed score, the version (IPFS CID) of the scoring algorithm used, and the timestamp at which the score was generated such that further on-chain activity doesn't render the "point-in-time" Janka score invalid.
  - As part of an attestation, users are required to provide a sufficient amount of "at risk" Ether to disincentivize fraudulent behavior.
  - The user is responsible for paying for the cost of gas as part of the attestation.
- Separately, Verifier processes hosted on Gelato Web3 Functions continually monitor emitted on-chain events, checking each attested score for validity by using the same scoring algorithm from IPFS.
  - If a fraudulent score is detected, the Verifier issues a `challenge()` call by providing the correct score.
  - A successful challenge will cause the attester to forfeit their at-risk Ether, and that then gets sent to the Verifier as an incentive.
  - Although issuing a `challenge()` call will cost the Verifier gas, the incentive payment (claiming the attester's at-risk Ether) outweighs any cost.
- Finally, if a user's attestation doesn't get successfully challenged within the challenge period, the user becomes eligible to withdraw ("reclaim") their at-risk Ether.
  - Once a user withdraws their at-risk Ether after the challenge period allows for it, the attestation is unable to be challenged.

Future versions may augment or replace the existing workflow with a zero-knowledge methodology and/or the use of oracle networks.

### Installation

```sh
yarn install
```

### Development

To run the test suite and watch for (re-run on) changes:

```sh
yarn test
```

To additionally show code test coverage:

```sh
yarn coverage
```

To show gas usage estimation:

```sh
REPORT_GAS=true yarn test
```

### Deployment

Copy the `.env.sample` file in the project's root and supply the pertinent environment variables:

```sh
cp .env.sample .env
# Edit .env and fill in the pertinent environment variables.
```

Then, run the deploy script:

```sh
npx hardhat run --network goerli scripts/deploy.ts
```
