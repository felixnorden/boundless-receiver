// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.30;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Steel } from "@risc0/contracts/steel/Steel.sol";
import { IRiscZeroVerifier } from "@risc0/contracts/IRiscZeroVerifier.sol";
import { ConsensusState, Checkpoint } from "./tseth.sol";

contract RiscZeroTransceiver is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    bytes32 public imageID;
    address public immutable verifier;
    uint24 public permissibleTimespan;

    ConsensusState private currentState;

    struct Journal {
        ConsensusState preState;
        ConsensusState postState;
    }

    event Transition(bytes32 preRoot, bytes32 indexed postRoot, ConsensusState preState, ConsensusState postState);

    error InvalidArgument();
    error InvalidPreState();
    error PermissibleTimespanLapsed();

    constructor(
        ConsensusState memory startingState,
        uint24 permissibleTimespan_,
        address verifier_,
        bytes32 imageID_,
        address admin,
        address roleAdmin
    ) {
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(DEFAULT_ADMIN_ROLE, roleAdmin);

        currentState = startingState;
        permissibleTimespan = permissibleTimespan_;
        verifier = verifier_;
        imageID = imageID_;
    }

    function transition(bytes calldata journalData, bytes calldata seal) external {
        Journal memory journal = abi.decode(journalData, (Journal));
        if (!_compareConsensusState(currentState, journal.preState)) {
            revert InvalidPreState();
        }
        if (!_permissibleTransition(journal.preState, journal.postState)) {
            revert PermissibleTimespanLapsed();
        }

        bytes32 journalHash = sha256(journalData);
        IRiscZeroVerifier(verifier).verify(seal, imageID, journalHash);

        currentState = journal.postState;
        emit Transition(
            journal.preState.currentJustifiedCheckpoint.root,
            journal.postState.currentJustifiedCheckpoint.root,
            journal.preState,
            journal.postState
        );
    }

    function checkpoint() external view returns (Checkpoint memory current) {
        current = currentState.currentJustifiedCheckpoint;
    }

    function updateImageID(bytes32 newImageID) external onlyRole(ADMIN_ROLE) {
        if (newImageID == imageID) revert InvalidArgument();
        imageID = newImageID;
    }

    function updatePermissibleTimespan(uint24 newPermissibleTimespan) external onlyRole(ADMIN_ROLE) {
        if (newPermissibleTimespan == permissibleTimespan) revert InvalidArgument();
        permissibleTimespan = newPermissibleTimespan;
    }

    function _compareConsensusState(ConsensusState memory a, ConsensusState memory b) internal pure returns (bool) {
        return _compareCheckpoint(a.currentJustifiedCheckpoint, b.currentJustifiedCheckpoint)
            && _compareCheckpoint(a.finalizedCheckpoint, b.finalizedCheckpoint);
    }

    function _compareCheckpoint(Checkpoint memory a, Checkpoint memory b) internal pure returns (bool) {
        return a.epoch == b.epoch && a.root == b.root;
    }

    function _permissibleTransition(
        ConsensusState memory pre,
        ConsensusState memory post
    )
        internal
        view
        returns (bool)
    {
        uint256 transitionTimespan = post.currentJustifiedCheckpoint.epoch - pre.currentJustifiedCheckpoint.epoch;
        return transitionTimespan <= uint256(permissibleTimespan);
    }
}
