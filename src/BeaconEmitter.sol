// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.30;

import { IWormhole } from "wormhole-sdk/interfaces/IWormhole.sol";

/**
 * @title BeaconEmitter
 * @notice Read beacon block roots via EIP-4788 and emit them as multicast Wormhole messages.
 *
 * @dev Note this must be deployed on a chain that uses beacon chain consensus and supports EIP-4788, such as Ethereum
 * or Gnosis
 * @dev The block root for a given slot can only be retrieved while it is in the beacon roots history buffer, which is
 * 8191 slots (about 27 hours) on Ethereum.
 * @dev A receiver must check that messages are from the correct chain/contract before processing them
 *
 */
contract BeaconEmitter {
    uint8 constant CONSISTENCY_LEVEL = 0; // Block containing message must be finalized
    uint64 constant SLOTS_PER_EPOCH = 32; // Seconds per slot, as per Ethereum's beacon chain

    IWormhole public immutable wormhole;
    uint256 public immutable genesisBlockTimestamp;

    /// @notice Creates a new BeaconEmitter contract.
    /// @param _wormhole The address of the Wormhole core contract.
    /// @param _genesisBlockTimestamp The timestamp of the genesis beacon block of the chain this contract is deployed
    /// on. 1606824000 for Ethereum mainnet.
    constructor(IWormhole _wormhole, uint256 _genesisBlockTimestamp) {
        wormhole = _wormhole;
        genesisBlockTimestamp = _genesisBlockTimestamp;
    }

    function emitForEpoch(uint64 _epoch) external payable {
        uint256 wormholeFee = wormhole.messageFee();

        bytes32 blockRoot = Beacon.findBlockRoot(genesisBlockTimestamp, _epoch * SLOTS_PER_EPOCH);

        wormhole.publishMessage{ value: wormholeFee }(0, abi.encode(_epoch, blockRoot), CONSISTENCY_LEVEL);
    }
}

/// @title Beacon Library
library Beacon {
    /// @notice The address of the Beacon roots contract. This is an immutable system contract so can be hard-coded
    /// @dev https://eips.ethereum.org/EIPS/eip-4788
    address internal constant BEACON_ROOTS_ADDRESS = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;

    /// @notice The length of the beacon roots ring buffer.
    uint256 internal constant BEACON_ROOTS_HISTORY_BUFFER_LENGTH = 8191;

    /// @dev Timestamp out of range for the the beacon roots precompile.
    error TimestampOutOfRange();

    /// @dev No block root is found using the beacon roots precompile.
    error NoBlockRootFound();

    /// @notice Attempts to find the block root for the given slot.
    /// @param _slot The slot to get the block root for.
    /// @return blockRoot The beacon block root of the given slot.
    /// @dev BEACON_ROOTS returns a block root for a given parent block's timestamp. To get the block root for slot
    ///      N, you use the timestamp of slot N+1. If N+1 is not available, you use the timestamp of slot N+2, and
    //       so on.
    function findBlockRoot(uint256 _genesisBlockTimestamp, uint64 _slot) public view returns (bytes32 blockRoot) {
        uint256 currBlockTimestamp = _genesisBlockTimestamp + ((_slot + 1) * 12);

        uint256 earliestBlockTimestamp = block.timestamp - (BEACON_ROOTS_HISTORY_BUFFER_LENGTH * 12);
        if (currBlockTimestamp <= earliestBlockTimestamp) {
            revert TimestampOutOfRange();
        }

        while (currBlockTimestamp <= block.timestamp) {
            (bool success, bytes memory result) = BEACON_ROOTS_ADDRESS.staticcall(abi.encode(currBlockTimestamp));
            if (success && result.length > 0) {
                return abi.decode(result, (bytes32));
            }

            unchecked {
                currBlockTimestamp += 12;
            }
        }

        revert NoBlockRootFound();
    }
}
