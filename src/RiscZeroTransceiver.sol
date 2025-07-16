// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.30;

import { ConsensusState } from "./tseth.sol";

contract RiscZeroTransceiver {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct Journal {
        ConsensusState preState;
        ConsensusState postState;
    }
}
