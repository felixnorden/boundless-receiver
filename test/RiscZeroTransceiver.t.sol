// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.30;

import { IRiscZeroVerifier } from "@risc0/contracts/IRiscZeroVerifier.sol";
import { ConsensusState, Checkpoint } from "../src/tseth.sol";
import { RiscZeroTransceiver } from "../src/RiscZeroTransceiver.sol";

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

struct Proof {
    uint256 epoch;
    bytes journal;
    bytes seal;
    bytes request_id;
    uint256 block_number;
    uint256 block_timestamp;
    bytes32 fulfillment_tx_hash;
    uint256 fulfillment_chain_id;
    uint256 created_at;
    bytes32 image_id;
    bytes receipt;
}

contract RiscZeroTransceiverTest is Test {
    RiscZeroTransceiver rzt;
    ConsensusState root;
    bytes32 imageID;
    address verifier;
    uint24 permissibleTimespan;
    address admin;
    address user;

    address wormhole;
    address beaconEmitter;
    uint16 emitterChainId;

    function setUp() public {
        string memory proofData = vm.readFile("./test/proof.json");

        RiscZeroTransceiver.Journal memory journal =
            abi.decode(vm.parseJsonBytes(proofData, ".journal"), (RiscZeroTransceiver.Journal));
        root = journal.postState;
        imageID = vm.parseJsonBytes32(proofData, ".image_id");
        permissibleTimespan = 3600 * 24 * 3; // 72 hr timespan
        verifier = address(0x1337);
        admin = address(0xA11CE);
        user = address(0xB0B);

        wormhole = address(0x1234);
        beaconEmitter = address(0x5678);
        emitterChainId = 1;

        rzt = new RiscZeroTransceiver(
            root, permissibleTimespan, verifier, imageID, wormhole, beaconEmitter, emitterChainId, admin, admin
        );
    }

    function test_UserHasNoAdminRole() public view {
        assertFalse(rzt.hasRole(rzt.ADMIN_ROLE(), user));
    }

    function test_AdminHasAdminRole() public view {
        assertTrue(rzt.hasRole(rzt.ADMIN_ROLE(), admin));
    }

    function test_AdminHasDefaultAdminRole() public view {
        assertTrue(rzt.hasRole(rzt.DEFAULT_ADMIN_ROLE(), admin));
    }

    function testFuzz_AdminCanUpdatePermissibleTimespan(uint24 newPermissibleTimespan) public {
        vm.prank(admin);
        if (newPermissibleTimespan == permissibleTimespan) {
            vm.expectRevert(RiscZeroTransceiver.InvalidArgument.selector);
        }
        rzt.updatePermissibleTimespan(newPermissibleTimespan);

        if (newPermissibleTimespan != permissibleTimespan) {
            vm.assertEq(rzt.permissibleTimespan(), newPermissibleTimespan);
        }
    }

    function testFuzz_AdminCanUpdateImageID(bytes32 newImageID) public {
        vm.prank(admin);
        if (newImageID == imageID) {
            vm.expectRevert(RiscZeroTransceiver.InvalidArgument.selector);
        }
        rzt.updateImageID(newImageID);

        if (newImageID != imageID) {
            vm.assertEq(rzt.imageID(), newImageID);
        }
    }

    function test_ManualTransitionByAdmin() public {
        RiscZeroTransceiver.Journal memory journal = RiscZeroTransceiver.Journal({
            preState: root,
            postState: ConsensusState({
                currentJustifiedCheckpoint: Checkpoint({ epoch: 1, root: bytes32(uint256(1)) }),
                finalizedCheckpoint: Checkpoint({ epoch: 1, root: bytes32(uint256(1)) })
            })
        });

        bytes memory journalData = abi.encode(journal);

        vm.expectEmit(true, true, true, true);
        emit Transitioned(
            journal.preState.finalizedCheckpoint.root,
            journal.postState.finalizedCheckpoint.root,
            journal.preState,
            journal.postState
        );

        vm.prank(admin);
        rzt.manualTransition(journalData);

        assertEq(rzt.consensusCheckpoint().epoch, journal.postState.finalizedCheckpoint.epoch);
        assertEq(rzt.consensusCheckpoint().root, journal.postState.finalizedCheckpoint.root);
    }

    function test_ManualTransitionByNonAdminReverts() public {
        RiscZeroTransceiver.Journal memory journal = RiscZeroTransceiver.Journal({
            preState: root,
            postState: ConsensusState({
                currentJustifiedCheckpoint: Checkpoint({ epoch: 1, root: bytes32(uint256(1)) }),
                finalizedCheckpoint: Checkpoint({ epoch: 1, root: bytes32(uint256(1)) })
            })
        });

        bytes memory journalData = abi.encode(journal);

        vm.prank(user);
        vm.expectRevert();
        rzt.manualTransition(journalData);
    }

    function test_ManualTransitionIgnoresPreState() public {
        RiscZeroTransceiver.Journal memory journal = RiscZeroTransceiver.Journal({
            preState: ConsensusState({
                currentJustifiedCheckpoint: Checkpoint({ epoch: 1, root: bytes32(uint256(1)) }),
                finalizedCheckpoint: Checkpoint({ epoch: 1, root: bytes32(uint256(1)) })
            }),
            postState: ConsensusState({
                currentJustifiedCheckpoint: Checkpoint({ epoch: 2, root: bytes32(uint256(2)) }),
                finalizedCheckpoint: Checkpoint({ epoch: 2, root: bytes32(uint256(2)) })
            })
        });

        bytes memory journalData = abi.encode(journal);

        vm.expectEmit(true, true, true, true);
        emit Transitioned(
            journal.preState.finalizedCheckpoint.root,
            journal.postState.finalizedCheckpoint.root,
            journal.preState,
            journal.postState
        );

        vm.prank(admin);
        rzt.manualTransition(journalData);
        assertEq(rzt.consensusCheckpoint().epoch, journal.postState.finalizedCheckpoint.epoch);
        assertEq(rzt.consensusCheckpoint().root, journal.postState.finalizedCheckpoint.root);
    }

    function test_ManualTransitionPermissibleTimespanLapsedSucceeds() public {
        RiscZeroTransceiver.Journal memory journal = RiscZeroTransceiver.Journal({
            preState: root,
            postState: ConsensusState({
                currentJustifiedCheckpoint: Checkpoint({
                    epoch: root.currentJustifiedCheckpoint.epoch + permissibleTimespan + 1,
                    root: bytes32(uint256(1))
                }),
                finalizedCheckpoint: Checkpoint({
                    epoch: root.finalizedCheckpoint.epoch + permissibleTimespan + 1,
                    root: bytes32(uint256(1))
                })
            })
        });

        bytes memory journalData = abi.encode(journal);

        vm.expectEmit(true, true, true, true);
        emit Transitioned(
            journal.preState.finalizedCheckpoint.root,
            journal.postState.finalizedCheckpoint.root,
            journal.preState,
            journal.postState
        );

        vm.prank(admin);
        rzt.manualTransition(journalData);
        assertEq(rzt.consensusCheckpoint().epoch, journal.postState.finalizedCheckpoint.epoch);
        assertEq(rzt.consensusCheckpoint().root, journal.postState.finalizedCheckpoint.root);
    }

    event Transitioned(bytes32 preRoot, bytes32 indexed postRoot, ConsensusState preState, ConsensusState postState);
}
