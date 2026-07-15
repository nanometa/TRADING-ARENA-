// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RitualAddresses} from "../src/RitualAddresses.sol";

/// @title SystemAddresses — smoke test anti-substitution
/// @notice Vérifie que les adresses système référencées correspondent EXACTEMENT
///         aux adresses Ritual vérifiées (Req 10.5, 10.6). Toute substitution
///         accidentelle d'une adresse ferait échouer ce test.
/// _Requirements: 10.1, 10.5, 10.6_
contract SystemAddressesTest is Test {
    function test_systemAddressesMatchVerified() public pure {
        assertEq(
            RitualAddresses.RITUAL_WALLET,
            0x532F0dF0896F353d8C3DD8cc134e8129DA2a3948,
            "RitualWallet"
        );
        assertEq(
            RitualAddresses.SCHEDULER,
            0x56e776BAE2DD60664b69Bd5F865F1180ffB7D58B,
            "Scheduler"
        );
        assertEq(
            RitualAddresses.TEE_REGISTRY,
            0x9644e8562cE0Fe12b4deeC4163c064A8862Bf47F,
            "TEEServiceRegistry"
        );
        assertEq(
            RitualAddresses.ASYNC_TRACKER,
            0xC069FFCa0389f44eCA2C626e55491b0ab045AEF5,
            "AsyncJobTracker"
        );
        assertEq(
            RitualAddresses.ASYNC_DELIVERY,
            0x5A16214fF555848411544b005f7Ac063742f39F6,
            "AsyncDelivery"
        );
        assertEq(
            RitualAddresses.LLM_PRECOMPILE,
            0x0000000000000000000000000000000000000802,
            "LLM precompile 0x0802"
        );
        assertEq(
            RitualAddresses.HTTP_PRECOMPILE,
            0x0000000000000000000000000000000000000801,
            "HTTP precompile 0x0801"
        );
        assertEq(
            RitualAddresses.DKMS_PRECOMPILE,
            0x000000000000000000000000000000000000081B,
            "DKMS precompile 0x081B"
        );
    }

    function test_schedulerConstants() public pure {
        assertEq(RitualAddresses.MAX_TTL, 500, "MAX_TTL");
        assertEq(RitualAddresses.MAX_LIFESPAN, 10_000, "MAX_LIFESPAN");
        assertEq(RitualAddresses.CAP_HTTP_CALL, 0, "HTTP_CALL capability");
    }
}
