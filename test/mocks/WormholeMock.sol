// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.30;

import { IWormhole } from "wormhole-sdk/interfaces/IWormhole.sol";
import { toWormholeFormat } from "wormhole-sdk/Utils.sol";

contract WormholeMock is IWormhole {
    struct MockVM {
        uint64 epoch;
        bytes32 root;
        address emitter;
        uint16 emitterChainId;
    }

    mapping(bytes => MockVM) private _encodedVMs;
    address public beaconEmitter;
    uint16 public emitterChainId;

    constructor() { }

    function setMockVM(
        bytes calldata encodedVM,
        uint64 epoch,
        bytes32 root,
        address emitter,
        uint16 chainId
    )
        external
    {
        _encodedVMs[encodedVM] = MockVM({ epoch: epoch, root: root, emitter: emitter, emitterChainId: chainId });
    }

    function parseAndVerifyVM(bytes calldata encodedVM)
        external
        view
        returns (VM memory vm, bool valid, string memory reason)
    {
        MockVM memory mock = _encodedVMs[encodedVM];

        if (mock.emitter == address(0)) {
            return (vm, false, "Invalid VM");
        }

        vm.emitterAddress = toWormholeFormat(mock.emitter);
        vm.emitterChainId = mock.emitterChainId;
        vm.payload = abi.encode(mock.epoch, mock.root);

        valid = true;
        reason = "";
    }

    // Stub implementations for unused functions
    function publishMessage(
        uint32 nonce,
        bytes calldata payload,
        uint8 consistencyLevel
    )
        external
        payable
        returns (uint64 sequence)
    { }

    function parseVM(bytes calldata encodedVM) external pure returns (VM memory vm) { }

    function verifyVM(VM memory vm) external view returns (bool valid, string memory reason) { }

    function verifySignatures(
        bytes32 hash,
        Signature[] memory signatures,
        address[] memory signers
    )
        external
        pure
        returns (bool valid, string memory reason)
    { }

    function initialize() external override { }

    function verifySignatures(
        bytes32 hash,
        Signature[] memory signatures,
        GuardianSet memory guardianSet
    )
        external
        pure
        override
        returns (bool valid, string memory reason)
    { }

    function quorum(uint256 numGuardians) external pure override returns (uint256 numSignaturesRequiredForQuorum) { }

    function getGuardianSet(uint32 index) external view override returns (GuardianSet memory) { }

    function getCurrentGuardianSetIndex() external view override returns (uint32) { }

    function getGuardianSetExpiry() external view override returns (uint32) { }

    function governanceActionIsConsumed(bytes32 hash) external view override returns (bool) { }

    function isInitialized(address impl) external view override returns (bool) { }

    function chainId() external view override returns (uint16) { }

    function isFork() external view override returns (bool) { }

    function governanceChainId() external view override returns (uint16) { }

    function governanceContract() external view override returns (bytes32) { }

    function messageFee() external view override returns (uint256) { }

    function evmChainId() external view override returns (uint256) { }

    function nextSequence(address emitter) external view override returns (uint64) { }

    function parseContractUpgrade(bytes memory encodedUpgrade)
        external
        pure
        override
        returns (ContractUpgrade memory cu)
    { }

    function parseGuardianSetUpgrade(bytes memory encodedUpgrade)
        external
        pure
        override
        returns (GuardianSetUpgrade memory gsu)
    { }

    function parseSetMessageFee(bytes memory encodedSetMessageFee)
        external
        pure
        override
        returns (SetMessageFee memory smf)
    { }

    function parseTransferFees(bytes memory encodedTransferFees)
        external
        pure
        override
        returns (TransferFees memory tf)
    { }

    function parseRecoverChainId(bytes memory encodedRecoverChainId)
        external
        pure
        override
        returns (RecoverChainId memory rci)
    { }

    function submitContractUpgrade(bytes memory _vm) external override { }

    function submitSetMessageFee(bytes memory _vm) external override { }

    function submitNewGuardianSet(bytes memory _vm) external override { }

    function submitTransferFees(bytes memory _vm) external override { }

    function submitRecoverChainId(bytes memory _vm) external override { }
}
