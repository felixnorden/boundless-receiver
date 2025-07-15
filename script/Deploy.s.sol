// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28 <0.9.0;

import { Foo } from "../src/Foo.sol";

import { BaseScript } from "./Base.s.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/guides/scripting-with-solidity
contract Deploy is BaseScript {
    function run() public broadcast returns (Foo foo) {
        string memory name = vm.envOr("NAME", string("Foo"));
        string memory symbol = vm.envOr("SYMBOL", string("FOO"));
        foo = new Foo(name, symbol);
    }
}
