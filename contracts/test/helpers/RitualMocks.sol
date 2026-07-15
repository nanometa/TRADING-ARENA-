// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {ITEEServiceRegistry} from "../../src/interfaces/IRitualSystem.sol";
import {RitualAddresses} from "../../src/RitualAddresses.sol";

/// @title RitualMocks
/// @notice Outils de mock des contrats système / precompiles Ritual via vm.mockCall.
///         On ne teste jamais le comportement réel des services Ritual, seulement
///         notre orchestration (Req : tests avec precompiles mockés).
library RitualMocks {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @notice Mock du Scheduler.schedule(...) (overload complet, 10 args) → callId.
    function mockSchedulerReturns(uint256 callId) internal {
        // Sélecteur de l'overload complet.
        bytes4 sel = bytes4(
            keccak256("schedule(bytes,uint32,uint32,uint32,uint32,uint32,uint256,uint256,uint256,address)")
        );
        vm.mockCall(RitualAddresses.SCHEDULER, abi.encodeWithSelector(sel), abi.encode(callId));
    }

    /// @notice Mock de AsyncJobTracker.hasPendingJobForSender(address) → pending.
    function mockNoPendingJob(bool pending) internal {
        vm.mockCall(
            RitualAddresses.ASYNC_TRACKER,
            abi.encodeWithSignature("hasPendingJobForSender(address)"),
            abi.encode(pending)
        );
    }

    /// @notice Mock de Scheduler.approveScheduler(address) → no-op (réussit).
    function mockApproveScheduler() internal {
        vm.mockCall(
            RitualAddresses.SCHEDULER,
            abi.encodeWithSignature("approveScheduler(address)"),
            abi.encode()
        );
    }

    /// @notice Mock de RitualWallet.balanceOf(address) → balance.
    function mockWalletBalance(uint256 balance) internal {
        vm.mockCall(
            RitualAddresses.RITUAL_WALLET,
            abi.encodeWithSignature("balanceOf(address)"),
            abi.encode(balance)
        );
    }

    /// @notice Mock du LLM precompile : retourne un jobId pour tout appel (l'appel
    ///         réel est de l'ABI brute sans sélecteur).
    function mockLLMReturns(uint256 jobId) internal {
        vm.mockCall(
            RitualAddresses.LLM_PRECOMPILE,
            bytes(""),
            abi.encode(jobId)
        );
    }

    /// @notice Mock du LLM precompile renvoyant une ENVELOPPE LLM complète. Modèle
    ///         short-running async : la sortie réglée revient dans le retour de l'appel
    ///         (fulfilled-replay) et est décodée EN-TX. Construire l'enveloppe via
    ///         AgentTestBase._buildLLMResponse(content, hasError).
    function mockLLMResponse(bytes memory envelope) internal {
        vm.mockCall(RitualAddresses.LLM_PRECOMPILE, bytes(""), envelope);
    }

    /// @notice Mock du TEEServiceRegistry avec un exécuteur valide à l'adresse `tee`.
    function mockTeeRegistryWithExecutor(address tee) internal {
        ITEEServiceRegistry.Service[] memory services = new ITEEServiceRegistry.Service[](1);
        services[0] = ITEEServiceRegistry.Service({
            node: ITEEServiceRegistry.Node({
                paymentAddress: tee,
                teeAddress: tee,
                teeType: 1,
                publicKey: hex"04",
                endpoint: "https://tee.example",
                certPubKeyHash: bytes32(0),
                capability: RitualAddresses.CAP_HTTP_CALL
            }),
            isValid: true,
            workloadId: bytes32(0)
        });
        vm.mockCall(
            RitualAddresses.TEE_REGISTRY,
            abi.encodeWithSignature("getServicesByCapability(uint8,bool)"),
            abi.encode(services)
        );
    }

    /// @notice Mock du TEEServiceRegistry sans aucun exécuteur (liste vide) (Req 3.7).
    function mockTeeRegistryEmpty() internal {
        ITEEServiceRegistry.Service[] memory services = new ITEEServiceRegistry.Service[](0);
        vm.mockCall(
            RitualAddresses.TEE_REGISTRY,
            abi.encodeWithSignature("getServicesByCapability(uint8,bool)"),
            abi.encode(services)
        );
    }

    /// @notice Mock du precompile JQ (0x0803) : retourne `value` (uint256) pour tout
    ///         appel. L'appel réel est de l'ABI brute (string,string,uint8) sans sélecteur.
    function mockJqReturns(uint256 value) internal {
        vm.mockCall(
            RitualAddresses.JQ_PRECOMPILE,
            bytes(""),
            abi.encode(value)
        );
    }

    /// @notice Construit une réponse HTTP encodée comme le precompile 0x0801 :
    ///         (uint16 status, string[] hk, string[] hv, bytes body, string error).
    function encodeHttpResponse(uint16 status, string memory body)
        internal
        pure
        returns (bytes memory)
    {
        string[] memory empty = new string[](0);
        return abi.encode(status, empty, empty, bytes(body), "");
    }
}
