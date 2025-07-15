# Foundry Template

[![Open in Gitpod][gitpod-badge]][gitpod] [![Github Actions][gha-badge]][gha] [![Foundry][foundry-badge]][foundry] [![License: MIT][license-badge]][license]

A Foundry-based template for developing Solidity smart contracts, with sensible defaults.

## Overview

This template provides a robust foundation for Solidity smart contract development using:

- [Forge](https://github.com/foundry-rs/foundry/blob/master/forge): Compile, test, fuzz, format, and deploy smart contracts
- [Bun](https://bun.sh/): Modern package management (instead of git submodules)
- [Forge Std](https://github.com/foundry-rs/forge-std): Testing utilities and helpful contracts
- [Solhint](https://github.com/protofire/solhint): Solidity linting

## Installation

### Quick Start

Click the [`Use this template`](https://github.com/ignio-labs/foundry-template/generate) button at the top of the page.

Or install manually with `foundry`:

```sh
$ forge init --template ignio-labs/foundry-template my-project
$ cd my-project
$ bun install # install Solhint, OpenZeppelin Contracts and other deps
```

First time with Foundry? Check out the [installation guide](https://github.com/foundry-rs/foundry#installation).

### Monorepo Setup

For use within a monorepo (e.g., with [Turborepo](https://turbo.build/repo/docs)):

```sh
$ forge init --template ignio-labs/foundry-template packages/my-project --no-git
$ cd packages/my-project
$ bun install
```

**Note**: Using another package manager? Delete `bun.lock` and use your preferred tool (e.g., `pnpm install`).

## Development

### Dependencies

This template uses Node.js packages instead of git submodules for better scalability. To add dependencies:

1. Install via package manager: `bun install dependency-name`
   - From GitHub: `bun install github:username/repo-name`
2. Add to [remappings.txt](./remappings.txt): `dependency-name=node_modules/dependency-name`

OpenZeppelin Contracts comes pre-installed as an example.

### Testing

Write tests by importing `Test` from `forge-std`. Access cheatcodes via the `vm` property. Example test in [Foo.t.sol](./tests/Foo.t.sol).

For detailed logs, use the `-vvv` flag and [console.log](https://book.getfoundry.sh/faq?highlight=console.log#how-do-i-use-consolelog).

### Editor Support

- **VSCode**: Use with [Solidity extension](https://marketplace.visualstudio.com/items?itemName=NomicFoundation.hardhat-solidity). [Setup guide](https://book.getfoundry.sh/config/vscode)
- **(Neo)Vim**: Use `lspconfig` following these [instructions](https://github.com/NomicFoundation/hardhat-vscode/blob/development/server/README.md#neovim-lsp)

### CI/CD

GitHub Actions automatically lint and test on push/PR to `main`. Configure in [.github/workflows/ci.yml](./.github/workflows/ci.yml).

## Usage

### Common Commands

```sh
# Build
$ forge build

# Test
$ forge test
$ forge test --gas-report # CLI-based gas report
$ bun run test:coverage
$ bun run test:coverage:report  # Requires lcov: brew install lcov

# Linting & Formatting
$ bun run lint
$ forge fmt

# Deployment
$ forge script script/Deploy.s.sol --broadcast --fork-url http://localhost:8545 [--verify]
# NOTE: --verify will work iff the `etherscan` section in foundry.toml
# is specified for the dedicated rpc

# With wallet management:
$ forge script script/Deploy.s.sol --broadcast --fork-url http://localhost:8545 \
  --account <wallet-name> --froms <wallet-address> --sender <wallet-address>
```

### Project Structure

Default configurations in:

```text
├── .editorconfig
├── .gitignore
├── .solhint.json
├── foundry.toml
└── remappings.txt
```

## Related Projects

- [PaulRBerg/foundry-template](https://github.com/PaulRBerg/foundry-template)
- [foundry-rs/forge-template](https://github.com/foundry-rs/forge-template)
- [abigger87/femplate](https://github.com/abigger87/femplate)
- [cleanunicorn/ethereum-smartcontract-template](https://github.com/cleanunicorn/ethereum-smartcontract-template)
- [FrankieIsLost/forge-template](https://github.com/FrankieIsLost/forge-template)

## License

This project is licensed under MIT.

[gitpod]: https://gitpod.io/#https://github.com/ignio-labs/foundry-template
[gitpod-badge]: https://img.shields.io/badge/Gitpod-Open%20in%20Gitpod-FFB45B?logo=gitpod
[gha]: https://github.com/ignio-labs/foundry-template/actions
[gha-badge]: https://github.com/ignio-labs/foundry-template/actions/workflows/ci.yml/badge.svg
[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg
[license]: https://opensource.org/licenses/MIT
[license-badge]: https://img.shields.io/badge/License-MIT-blue.svg
