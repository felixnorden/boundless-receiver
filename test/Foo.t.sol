// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Foo } from "../src/Foo.sol";

/// @dev If this is your first time with Forge, read this tutorial in the Foundry Book:
/// https://book.getfoundry.sh/forge/writing-tests
contract FooTest is Test {
    Foo internal foo;
    address holder;

    /// @dev A function invoked before each test case is run.
    function setUp() public virtual {
        // Instantiate the contract-under-test.
        foo = new Foo("Foo", "FOO");
        holder = vm.addr(0xb0b);
    }

    /// @dev Basic test. Run it with `forge test -vvv` or up to 5 `v` to see logs.
    function test_Example() external {
        console2.log("Minting tokens to holder:", holder);
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), holder, 100 ether);
        foo.mint(holder, 100 ether);
        assertEq(foo.balanceOf(holder), 100 ether);
    }

    /// @dev Fuzz test that provides random values for an unsigned integer, but which rejects zero as an input.
    /// If you need more sophisticated input validation, you should use the `bound` utility instead.
    /// See https://twitter.com/PaulRBerg/status/1622558791685242880
    function testFuzz_Example(uint256 amount) external {
        vm.assume(amount != 0); // or amount = bound(x, 1, 100)
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), holder, amount);
        foo.mint(holder, amount);
        assertEq(foo.balanceOf(holder), amount);
    }

    /// @dev Fork test that runs against an Ethereum Mainnet fork.
    function testFork_Example() external {
        vm.createSelectFork({ urlOrAlias: "mainnet", blockNumber: 16_428_000 });
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address holder_ = 0x7713974908Be4BEd47172370115e8b1219F4A5f0;
        uint256 actualBalance = IERC20(usdc).balanceOf(holder_);
        uint256 expectedBalance = 196_307_713.810457e6;
        assertEq(actualBalance, expectedBalance);
    }
}
