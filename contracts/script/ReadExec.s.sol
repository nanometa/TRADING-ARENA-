// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ITEEServiceRegistry} from "../src/interfaces/IRitualSystem.sol";
import {RitualAddresses} from "../src/RitualAddresses.sol";

/// @notice Read-only: discover the first valid HTTP (cap 0) and LLM (cap 1) TEE
///         executors off-chain (skill ritual-dapp-http model), to cache on the agent.
contract ReadExec is Script {
    function run() external view {
        ITEEServiceRegistry reg = ITEEServiceRegistry(RitualAddresses.TEE_REGISTRY);
        ITEEServiceRegistry.Service[] memory http = reg.getServicesByCapability(0, true);
        ITEEServiceRegistry.Service[] memory llm = reg.getServicesByCapability(1, true);

        console2.log("HTTP_COUNT", http.length);
        for (uint256 i = 0; i < http.length; i++) {
            if (http[i].isValid) {
                console2.log("HTTP_EXEC", http[i].node.teeAddress);
                break;
            }
        }
        console2.log("LLM_COUNT", llm.length);
        for (uint256 i = 0; i < llm.length; i++) {
            if (llm[i].isValid) {
                console2.log("LLM_EXEC", llm[i].node.teeAddress);
                break;
            }
        }
    }
}
