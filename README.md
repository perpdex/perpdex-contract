# perpdex-contract

This repository contains the core smart contracts for [PerpDEX](https://perpdex.com/).

## Get Started

Please check out:

- [PerpDEX website](https://perpdex.com/)
<!-- - [PerpDEX docs](https://docs.perpdex.com/) -->

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

Target files

- all *.sol files in contracts dir (except for contracts/test)
