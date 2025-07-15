// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.30;

import { ConsensusState } from "./tseth.sol";

struct Journal {
    ConsensusState preState;
    ConsensusState postState;
}

contract RiscZeroTransceiver { }
