// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.30;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IRiscZeroVerifier } from "@risc0/contracts/IRiscZeroVerifier.sol";
import { ConsensusState, Checkpoint } from "./tseth.sol";
import { IWormhole } from "wormhole-sdk/interfaces/IWormhole.sol";
import { toWormholeFormat } from "wormhole-sdk/Utils.sol";

contract RiscZeroTransceiver is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct CheckpointAttestation {
        bool wormholeConfirmed;
        bool rzConfirmed;
    }

    struct Journal {
        ConsensusState preState;
        ConsensusState postState;
    }

    ConsensusState private currentState;

    Checkpoint private latestCheckpoint;

    bytes32 public imageID;

    IWormhole public immutable WORMHOLE;
    /// @notice The address of the approved BeaconEmitter contract deployment
    bytes32 public immutable BEACON_EMITTER;

    address public immutable VERIFIER;

    uint24 public permissibleTimespan;

    /// @notice The chain ID where the approved BeaconEmitter is deployed.
    uint16 public immutable EMITTER_CHAIN_ID;

    mapping(bytes32 blockRoot => CheckpointAttestation attestation) private attestations;

    event Transitioned(bytes32 preRoot, bytes32 indexed postRoot, ConsensusState preState, ConsensusState postState);
    event Confirmed(uint64 indexed epoch, bytes32 indexed root);

    error InvalidArgument();
    error InvalidPreState();
    error PermissibleTimespanLapsed();
    error UnauthorizedEmitterChainId();
    error UnauthorizedEmitterAddress();

    constructor(
        ConsensusState memory startingState,
        uint24 permissibleTimespan_,
        address verifier,
        bytes32 imageID_,
        address wormhole,
        address beaconEmitter,
        uint16 emitterChainId,
        address admin,
        address roleAdmin
    ) {
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(DEFAULT_ADMIN_ROLE, roleAdmin);

        currentState = startingState;
        permissibleTimespan = permissibleTimespan_;
        imageID = imageID_;
        VERIFIER = verifier;
        WORMHOLE = IWormhole(wormhole);
        BEACON_EMITTER = toWormholeFormat(beaconEmitter);
        EMITTER_CHAIN_ID = emitterChainId;
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
        IRiscZeroVerifier(VERIFIER).verify(seal, imageID, journalHash);

        currentState = journal.postState;
        Checkpoint memory finalizedCheckpoint = journal.postState.finalizedCheckpoint;
        CheckpointAttestation storage attestation = attestations[finalizedCheckpoint.root];
        attestation.rzConfirmed = true;
        if (attestation.wormholeConfirmed && attestation.rzConfirmed) {
            _updateLatestCheckpoint(finalizedCheckpoint.epoch, finalizedCheckpoint.root);
        }

        emit Transitioned(
            journal.preState.finalizedCheckpoint.root,
            journal.postState.finalizedCheckpoint.root,
            journal.preState,
            journal.postState
        );
    }

    function receiveWormholeMessage(bytes calldata encodedVM) external {
        (IWormhole.VM memory vm, bool valid, string memory reason) = WORMHOLE.parseAndVerifyVM(encodedVM);
        if (!valid) {
            revert(reason);
        }
        if (vm.emitterChainId != EMITTER_CHAIN_ID) {
            revert UnauthorizedEmitterChainId();
        }
        if (vm.emitterAddress != BEACON_EMITTER) {
            revert UnauthorizedEmitterAddress();
        }

        (uint64 epoch, bytes32 blockRoot) = abi.decode(vm.payload, (uint64, bytes32));

        CheckpointAttestation storage attestation = attestations[blockRoot];
        attestation.wormholeConfirmed = true;
        if (attestation.wormholeConfirmed && attestation.rzConfirmed) {
            _updateLatestCheckpoint(epoch, blockRoot);
        }
    }

    /// @notice The latest finalized checkpoint provided by a ZKP.
    function consensusCheckpoint() external view returns (Checkpoint memory) {
        return currentState.finalizedCheckpoint;
    }

    /// @notice The latest 2/2 confirmed checkpoint by both a ZKP and Wormhole.
    function confirmedCheckpoint() external view returns (Checkpoint memory) {
        return latestCheckpoint;
    }

    function updateImageID(bytes32 newImageID) external onlyRole(ADMIN_ROLE) {
        if (newImageID == imageID) revert InvalidArgument();
        imageID = newImageID;
    }

    function updatePermissibleTimespan(uint24 newPermissibleTimespan) external onlyRole(ADMIN_ROLE) {
        if (newPermissibleTimespan == permissibleTimespan) revert InvalidArgument();
        permissibleTimespan = newPermissibleTimespan;
    }

    function _updateLatestCheckpoint(uint64 epoch, bytes32 blockRoot) internal {
        if (epoch > latestCheckpoint.epoch) {
            latestCheckpoint.epoch = epoch;
            latestCheckpoint.root = blockRoot;
            emit Confirmed(epoch, blockRoot);
        }
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
