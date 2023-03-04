# Janka Protocol
INTRO

---
OVERVIEW 
---
TECHNICAL
---
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
