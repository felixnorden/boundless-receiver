// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.30;

import { IRiscZeroVerifier, Receipt as RiscZeroReceipt } from "@risc0/contracts/IRiscZeroVerifier.sol";
import { RiscZeroMockVerifier } from "@risc0/contracts/test/RiscZeroMockVerifier.sol";
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
    bytes4 constant MOCK_SELECTOR = bytes4(0);
    RiscZeroTransceiver rzt;
    RiscZeroMockVerifier verifier;
    ConsensusState root;
    bytes32 imageID;
    uint24 permissibleTimespan;
    address admin;
    address user;
    RiscZeroTransceiver.Journal journal;
    address wormhole;
    address beaconEmitter;
    uint16 emitterChainId;

    function setUp() public {
        string memory proofData = vm.readFile("./test/proof.json");

        journal = abi.decode(vm.parseJsonBytes(proofData, ".journal"), (RiscZeroTransceiver.Journal));
        root = journal.preState;
        imageID = vm.parseJsonBytes32(proofData, ".image_id");
        permissibleTimespan = 3600 * 24 * 3; // 72 hr timespan
        admin = address(0xA11CE);
        user = address(0xB0B);

        wormhole = address(0x1234);
        beaconEmitter = address(0x5678);
        emitterChainId = 1;

        verifier = new RiscZeroMockVerifier(MOCK_SELECTOR);
        rzt = new RiscZeroTransceiver(
            root, permissibleTimespan, address(verifier), imageID, wormhole, beaconEmitter, emitterChainId, admin, admin
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
        emit RiscZeroTransceiver.Transitioned(
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
        emit RiscZeroTransceiver.Transitioned(
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
        emit RiscZeroTransceiver.Transitioned(
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

    function test_TransitionSucceeds() public {
        RiscZeroReceipt memory receipt = verifier.mockProve(imageID, sha256(abi.encode(journal)));

        vm.startPrank(admin);
        rzt.transition(abi.encode(journal), receipt.seal);
        vm.stopPrank();

        assertEq(rzt.consensusCheckpoint().root, journal.postState.finalizedCheckpoint.root);
    }

    function test_TransitionFailsOnWrongPreState() public {
        RiscZeroTransceiver.Journal memory journal_ = RiscZeroTransceiver.Journal({
            preState: ConsensusState({
                currentJustifiedCheckpoint: Checkpoint({ epoch: 1, root: bytes32(uint256(1)) }),
                finalizedCheckpoint: Checkpoint({ epoch: 1, root: bytes32(uint256(1)) })
            }),
            postState: journal.postState
        });
        RiscZeroReceipt memory receipt = verifier.mockProve(imageID, sha256(abi.encode(journal_)));

        vm.expectRevert(RiscZeroTransceiver.InvalidPreState.selector);
        vm.startPrank(admin);
        rzt.transition(abi.encode(journal_), receipt.seal);
        vm.stopPrank();
    }

    function test_TransitionFailsOnImpermissibleSpan() public {
        RiscZeroTransceiver.Journal memory journal_ = RiscZeroTransceiver.Journal({
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
        RiscZeroReceipt memory receipt = verifier.mockProve(imageID, sha256(abi.encode(journal_)));

        vm.expectRevert(RiscZeroTransceiver.PermissibleTimespanLapsed.selector);
        vm.startPrank(admin);
        rzt.transition(abi.encode(journal_), receipt.seal);
        vm.stopPrank();
    }
}
