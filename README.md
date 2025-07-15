# Boundless Transceiver Project

## Implementation Plan

- [x] Set up relevant structs for the checkpoints, validation process, and journal
- [] Set up admin role with RBAC configuration
- [] Constructor configuration for (1) initial checkpoint to verify from, (2) allowed time span since last transition, (3) trusted R0 verifier address, (4) ImageID
- [] Verification function using the R0 verifier, ImageID, journal and seal.

### References

- <https://hackmd.io/QSDlFbuKToScQ43jISuvFA>

## Overview

This template provides a robust foundation for Solidity smart contract development using:

- [Forge](https://github.com/foundry-rs/foundry/blob/master/forge): Compile, test, fuzz, format, and deploy smart contracts
- [Bun](https://bun.sh/): Modern package management (instead of git submodules)
- [Forge Std](https://github.com/foundry-rs/forge-std): Testing utilities and helpful contracts
- [Solhint](https://github.com/protofire/solhint): Solidity linting

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
