// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {AgentWallet} from "../src/AgentWallet.sol";
import {TradingAgent} from "../src/TradingAgent.sol";

/// @title RefuelAgent
/// @notice Réapprovisionne un agent et PROLONGE son verrou de dépôt (lock).
///         Conforme au skill ritual-dapp-wallet : "new deposits only extend the
///         lock" et "you need a lock that covers your async operation window".
///         Le verrou expiré est la cause du blocage des cycles (garde-fou Req 2.4).
///
/// Variables d'environnement :
///   AGENT_ADDRESS   — adresse du TradingAgent
///   WALLET_ADDRESS  — adresse de l'AgentWallet dédié
///   REFUEL_AMOUNT   — montant natif à déposer (wei), défaut 0,05 RITUAL
///   LOCK_DURATION   — durée de verrouillage en blocs, défaut 200000 (~19h à 0,35s/bloc)
///
/// Usage :
///   AGENT_ADDRESS=0x.. WALLET_ADDRESS=0x.. forge script script/RefuelAgent.s.sol:RefuelAgent \
///     --rpc-url https://rpc.ritualfoundation.org --private-key $PK --broadcast
contract RefuelAgent is Script {
    function run() external {
        address agentAddr = vm.envAddress("AGENT_ADDRESS");
        address walletAddr = vm.envAddress("WALLET_ADDRESS");
        uint256 amount = vm.envOr("REFUEL_AMOUNT", uint256(0.05 ether));
        uint256 lockDuration = vm.envOr("LOCK_DURATION", uint256(200_000));

        AgentWallet wallet = AgentWallet(payable(walletAddr));
        TradingAgent agent = TradingAgent(payable(agentAddr));

        vm.startBroadcast();

        // 1) Redéposer avec un verrou long : le lock est monotone (ne fait que
        //    s'allonger), donc ceci PROLONGE la couverture du verrou.
        wallet.deposit{value: amount}(lockDuration);

        // 2) Mettre à jour le garde-fou côté agent (Req 2.4) avec la nouvelle
        //    expiration : block.number + lockDuration.
        agent.recordDepositLock(block.number + lockDuration);

        vm.stopBroadcast();

        console2.log("Agent reapprovisionne + verrou prolonge :");
        console2.log("  agent          :", agentAddr);
        console2.log("  wallet         :", walletAddr);
        console2.log("  depot ajoute   :", amount);
        console2.log("  nouveau verrou expire au bloc :", block.number + lockDuration);
    }
}
