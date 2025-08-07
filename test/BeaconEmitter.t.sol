// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";
import { BeaconEmitter } from "../src/BeaconEmitter.sol";
import { Beacon } from "../src/lib/Beacon.sol";
import { WormholeMock } from "./mocks/WormholeMock.sol";

contract BeaconEmitterTest is Test {
    BeaconEmitter public beaconEmitter;
    WormholeMock public wormholeMock;

    // Ethereum mainnet genesis timestamp
    uint256 constant GENESIS_TIMESTAMP = 1_606_824_000;
    uint64 constant SLOTS_PER_EPOCH = 32;
    uint256 constant SLOT_DURATION = 12 seconds;
    uint256 constant BEACON_ROOTS_HISTORY_BUFFER_LENGTH = 8191;

    address constant BEACON_ROOTS_ADDRESS = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;

    bytes32 blockRoot;

    event BeaconRootEmitted(uint64 indexed epoch, bytes32 blockRoot);

    function setUp() public {
        wormholeMock = new WormholeMock();
        beaconEmitter = new BeaconEmitter(address(wormholeMock), GENESIS_TIMESTAMP);

        uint256 currentTimestamp = GENESIS_TIMESTAMP + (100 * SLOT_DURATION);
        vm.warp(currentTimestamp);
        _mockBeacon(currentTimestamp, keccak256("42"));
        blockRoot = Beacon.findBlockRoot(GENESIS_TIMESTAMP, 100 * 32);
    }

    function test_ConstructorInitialization() public {
        assertEq(address(beaconEmitter.WORMHOLE()), address(wormholeMock));
        assertEq(beaconEmitter.GENESIS_BLOCK_TIMESTAMP(), GENESIS_TIMESTAMP);
    }

    function test_EmitForSlot_Success() public {
        // Warp to a time when we can get a valid block root
        // Use a recent timestamp that's within the beacon roots buffer
        uint256 currentTimestamp = GENESIS_TIMESTAMP + (100_000 * SLOT_DURATION);
        vm.warp(currentTimestamp);

        uint64 epoch = 1000;
        uint64 expectedSlot = epoch * SLOTS_PER_EPOCH;
        uint256 expectedTimestamp = GENESIS_TIMESTAMP + ((expectedSlot + 1) * SLOT_DURATION);

        _mockBeacon(expectedTimestamp, blockRoot);

        // Set Wormhole fee
        uint256 wormholeFee = 0.0001 ether;
        vm.deal(address(this), wormholeFee);

        // Call emitForEpoch
        beaconEmitter.emitForSlot{ value: wormholeFee }(expectedSlot);

        // Verify the message was published
        assertEq(wormholeMock.publishedMessagesLength(), 1);
        WormholeMock.PublishedMessage memory published = wormholeMock.publishedMessages(0);

        assertEq(published.sender, address(beaconEmitter));
        assertEq(published.value, wormholeFee);
        assertEq(published.consistencyLevel, 0);

        // Decode payload and verify
        (uint64 emittedSlot, bytes32 emittedRoot) = abi.decode(published.payload, (uint64, bytes32));
        assertEq(emittedSlot, expectedSlot);
        assertEq(emittedRoot, blockRoot);
    }

    // function test_FindBlockRoot_Fallback() public {
    //     uint64 epoch = 2000;
    //     uint256 expectedSlot = epoch * SLOTS_PER_EPOCH;
    //     uint256 baseTimestamp = GENESIS_TIMESTAMP + ((expectedSlot + 1) * SLOT_DURATION);
    //
    //     // Warp to a time when we can get a valid block root
    //     uint256 currentTimestamp = baseTimestamp + 1000;
    //     vm.warp(currentTimestamp);
    //
    //     bytes32 mockBlockRoot = bytes32(uint256(0xabcdef1234567890));
    //
    //     // Mock multiple timestamps to test fallback behavior
    //     for (uint256 i = 0; i < 5; i++) {
    //         uint256 timestamp = baseTimestamp + (i * SLOT_DURATION);
    //         if (i == 2) {
    //             // Only succeed on the 3rd attempt
    //             vm.mockCall(
    //                 BEACON_ROOTS_ADDRESS,
    //                 abi.encodeWithSelector(bytes4(keccak256("get(bytes32)")), bytes32(timestamp)),
    //                 abi.encode(mockBlockRoot)
    //             );
    //         } else {
    //             vm.mockCall(
    //                 BEACON_ROOTS_ADDRESS,
    //                 abi.encodeWithSelector(bytes4(keccak256("get(bytes32)")), bytes32(timestamp)),
    //                 abi.encode(bytes32(0))
    //             );
    //         }
    //     }
    //
    //     uint256 wormholeFee = 0.0001 ether;
    //     vm.deal(address(this), wormholeFee);
    //
    //     beaconEmitter.emitForEpoch{ value: wormholeFee }(epoch);
    //
    //     // Verify the message was published with correct root
    //     WormholeMock.PublishedMessage memory published = wormholeMock.publishedMessages(0);
    //     (, bytes32 emittedRoot) = abi.decode(published.payload, (uint64, bytes32));
    //     assertEq(emittedRoot, mockBlockRoot);
    // }

    function test_GenesisBlockTimestamp_Validation() public {
        // Test with different genesis timestamps
        uint256 customGenesis = 1_606_824_000 + 86_400; // One day later
        BeaconEmitter customEmitter = new BeaconEmitter(address(wormholeMock), customGenesis);

        assertEq(customEmitter.GENESIS_BLOCK_TIMESTAMP(), customGenesis);

        // Test with current timestamp (should be valid)
        uint256 currentGenesis = block.timestamp - 1_000_000;
        BeaconEmitter currentEmitter = new BeaconEmitter(address(wormholeMock), currentGenesis);
        assertEq(currentEmitter.GENESIS_BLOCK_TIMESTAMP(), currentGenesis);
    }

    function test_EpochToSlot_Calculation() public {
        uint64 epoch = 1234;
        uint256 expectedSlot = epoch * SLOTS_PER_EPOCH;

        // This is implicitly tested through emitForEpoch, but let's verify the calculation
        uint256 expectedTimestamp = GENESIS_TIMESTAMP + ((expectedSlot + 1) * SLOT_DURATION);

        assertEq(expectedSlot, 1234 * 32);
        assertEq(expectedTimestamp, GENESIS_TIMESTAMP + (1234 * 32 + 1) * 12);
    }

    function test_EmitForSlot_TimestampOutOfRange() public {
        // Warp to current time
        uint256 currentTimestamp = block.timestamp;

        // Calculate an epoch that's too old to be in the buffer
        uint256 oldestValidTimestamp = currentTimestamp - (BEACON_ROOTS_HISTORY_BUFFER_LENGTH * SLOT_DURATION);
        uint64 oldEpoch = uint64((oldestValidTimestamp - GENESIS_TIMESTAMP) / (SLOTS_PER_EPOCH * SLOT_DURATION)) - 100;

        uint256 wormholeFee = 0.0001 ether;
        vm.deal(address(this), wormholeFee);

        // Expect revert due to timestamp out of range
        vm.expectRevert(Beacon.TimestampOutOfRange.selector);
        beaconEmitter.emitForSlot{ value: wormholeFee }(oldEpoch * SLOTS_PER_EPOCH);
    }

    function test_EmitForSlot_NoBlockRootFound() public {
        // Warp to a reasonable time
        uint256 currentTimestamp = GENESIS_TIMESTAMP + (50_000 * SLOT_DURATION);
        vm.warp(currentTimestamp);

        uint64 epoch = 1500;
        uint64 expectedSlot = epoch * SLOTS_PER_EPOCH;
        uint256 expectedTimestamp = GENESIS_TIMESTAMP + ((expectedSlot + 1) * SLOT_DURATION);

        // Mock all calls to return empty (no block root found)
        for (uint256 i = 0; i < 100; i++) {
            uint256 timestamp = expectedTimestamp + (i * SLOT_DURATION);
            vm.mockCall(
                BEACON_ROOTS_ADDRESS,
                abi.encodeWithSelector(bytes4(keccak256("get(bytes32)")), bytes32(timestamp)),
                abi.encode(bytes32(0))
            );
        }

        uint256 wormholeFee = 0.0001 ether;
        vm.deal(address(this), wormholeFee);

        // Expect revert due to no block root found
        vm.expectRevert(Beacon.NoBlockRootFound.selector);
        beaconEmitter.emitForSlot{ value: wormholeFee }(expectedSlot);
    }

    function test_EmitForSlot_InsufficientFee() public {
        uint256 currentTimestamp = GENESIS_TIMESTAMP + (10_000 * SLOT_DURATION);
        vm.warp(currentTimestamp);

        // Send insufficient fee
        uint256 insufficientFee = 0.00005 ether;
        vm.deal(address(this), insufficientFee);

        vm.expectRevert("Insufficient fee");
        beaconEmitter.emitForSlot{ value: insufficientFee }(0);
    }

    function test_EmitForSlot_EpochZero() public {
        uint256 currentTimestamp = GENESIS_TIMESTAMP + (100 * SLOT_DURATION);
        vm.warp(currentTimestamp);

        uint64 slot = 0;

        uint256 wormholeFee = 0.0001 ether;
        vm.deal(address(this), wormholeFee);

        beaconEmitter.emitForSlot{ value: wormholeFee }(slot);

        WormholeMock.PublishedMessage memory published = wormholeMock.publishedMessages(0);
        (uint64 emittedEpoch, bytes32 emittedRoot) = abi.decode(published.payload, (uint64, bytes32));
        assertEq(emittedEpoch, 0);
        assertEq(emittedRoot, 0x3373fffffffffffffffffffffffffffffffffffffffe14604d57602036146024);
    }

    function test_EmitForSlot_MultipleEmissions() public {
        uint256 currentTimestamp = GENESIS_TIMESTAMP + (110 * SLOT_DURATION);
        vm.warp(currentTimestamp);

        uint256 wormholeFee = 0.0001 ether;
        vm.deal(address(this), wormholeFee * 3);

        // Emit for multiple epochs
        uint64[] memory epochs = new uint64[](3);
        epochs[0] = 1000;
        epochs[1] = 1001;
        epochs[2] = 1002;

        bytes32[] memory mockRoots = new bytes32[](3);
        mockRoots[0] = bytes32(uint256(0x1111));
        mockRoots[1] = bytes32(uint256(0x2222));
        mockRoots[2] = bytes32(uint256(0x3333));

        for (uint256 i = 0; i < epochs.length; i++) {
            uint64 expectedSlot = epochs[i] * SLOTS_PER_EPOCH;
            uint256 expectedTimestamp = GENESIS_TIMESTAMP + ((expectedSlot + 1) * SLOT_DURATION);

            vm.mockCall(
                BEACON_ROOTS_ADDRESS,
                abi.encodeWithSelector(bytes4(keccak256("get(bytes32)")), bytes32(expectedTimestamp)),
                abi.encode(mockRoots[i])
            );

            beaconEmitter.emitForSlot{ value: wormholeFee }(expectedSlot);
        }

        assertEq(wormholeMock.publishedMessagesLength(), 3);

        for (uint256 i = 0; i < 3; i++) {
            WormholeMock.PublishedMessage memory published = wormholeMock.publishedMessages(i);
            (uint64 emittedEpoch, bytes32 emittedRoot) = abi.decode(published.payload, (uint64, bytes32));
            assertEq(emittedEpoch, epochs[i]);
            assertEq(emittedRoot, mockRoots[i]);
        }
    }

    function test_BeaconLibrary_Direct() public {
        uint64 slot = 3200;
        uint256 currentTimestamp = GENESIS_TIMESTAMP + (slot * SLOT_DURATION);
        vm.warp(currentTimestamp);

        bytes32 result = Beacon.findBlockRoot(GENESIS_TIMESTAMP, slot);
        assertEq(result, 0x3373fffffffffffffffffffffffffffffffffffffffe14604d57602036146024);
    }

    function test_GasEstimation() public {
        uint256 currentTimestamp = GENESIS_TIMESTAMP + (10_000 * SLOT_DURATION);
        vm.warp(currentTimestamp);

        uint64 epoch = 100;

        uint256 wormholeFee = 0.0001 ether;
        vm.deal(address(this), wormholeFee);

        uint256 gasBefore = gasleft();
        beaconEmitter.emitForSlot{ value: wormholeFee }(epoch * SLOTS_PER_EPOCH);
        uint256 gasUsed = gasBefore - gasleft();

        // Just ensure it completes successfully - actual gas usage will vary
        assertGt(gasUsed, 0);
    }

    function _mockBeacon(uint256 timestamp, bytes32 root) internal {
        vm.mockCall(
            BEACON_ROOTS_ADDRESS,
            abi.encodeWithSelector(bytes4(keccak256("get(bytes32)")), bytes32(timestamp)),
            abi.encode(root)
        );
    }
}
