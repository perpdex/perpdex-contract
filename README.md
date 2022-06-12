# perpdex-contract

This repository contains the core smart contracts for [PerpDEX](https://perpdex.com/).

## Get Started

Please check out:

- [PerpDEX website](https://perpdex.com/)
<!-- - [PerpDEX docs](https://docs.perpdex.com/) -->

## deploy

```bash
npx hardhat deploy --network rinkeby
```

## verify

```bash
npx hardhat etherscan-verify --network rinkeby --force-license --license GPL-3.0
```

## Local Development

You need Node.js 16+ to build. Use [nvm](https://github.com/nvm-sh/nvm) to install it.

Clone this repository, install Node.js dependencies, and build the source code:

```bash
git clone git@github.com:perpdex/perpdex-contract.git
npm i
npm run build
```

If the installation failed on your machine, please try a vanilla install instead:

```bash
npm run clean
rm -rf node_modules/
rm package-lock.json
npm install
npm run build
```

Run all the test cases:

```bash
npm run test
```

## Changelog

See [CHANGELOG](https://github.com/perpdex/perpdex-contract/blob/main/CHANGELOG.md).

## Related Projects

- [perpdex-oracle-contract](https://github.com/perpdex/perpdex-oracle-contract)
- [perpdex-subgraph](https://github.com/perpdex/perpdex-subgraph)

## For auditors

Target repositories

- [perpdex-contract](https://github.com/perpdex/perpdex-contract)
- [perpdex-oracle-contract](https://github.com/perpdex/perpdex-oracle-contract)
- [perpdex-stablecoin](https://github.com/perpdex/perpdex-stablecoin)

Target revisions

- https://github.com/perpdex/perpdex-contract/tree/audit-20220612 ( 2008957b77dd9e5772e0178369779a8b4573f315 )
- https://github.com/perpdex/perpdex-oracle-contract/tree/audit-20220612 ( c0935a04d78eae3c7daeeeab845d77af24f68b28 )
- https://github.com/perpdex/perpdex-stablecoin/tree/audit-20220612 (fbd07e8665f056d112f298b43a44d266ee25e856)

Target files

- all *.sol files in contracts dir (except for contracts/test)
