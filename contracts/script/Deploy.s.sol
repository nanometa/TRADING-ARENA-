// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Leaderboard} from "../src/Leaderboard.sol";
import {SimpleMarket} from "../src/SimpleMarket.sol";
import {AgentFactory} from "../src/AgentFactory.sol";
import {AgentDeployer} from "../src/AgentDeployer.sol";

/// @title Deploy
/// @notice Déploie l'arène complète sur le Ritual Chain Testnet (Chain ID 1979) (Req 10.1).
///
/// Ordre de déploiement (dépendances) :
///   1. Leaderboard
///   2. SimpleMarket (câblé au Leaderboard)
///   3. AgentFactory (câblée au marché + leaderboard)
///   4. Câblage des autorisations croisées :
///      - market.setFactory(factory)            → la factory peut enregistrer des agents
///      - leaderboard.setMarket(market)          → source des prix/capital/position
///      - leaderboard.setScoreUpdater(market)    → le marché met à jour les scores aux trades
///      - leaderboard.setRegistrar(factory)      → la factory expose les agents à la création
///
/// Usage :
///   forge script script/Deploy.s.sol:Deploy \
///     --rpc-url https://rpc.ritualfoundation.org \
///     --private-key $PRIVATE_KEY --broadcast
contract Deploy is Script {
    // Réserves initiales de l'AMM (prix initial 1:1).
    // Réserves VOLONTAIREMENT PETITES : avec peu d'agents (3-5) et un petit budget,
    // de petites réserves rendent le prix SENSIBLE — chaque trade le fait bouger
    // visiblement (marché "vivant" pour la démo). De grosses réserves rendraient
    // le prix quasi immobile faute de volume.
    uint256 internal constant RESERVE_BASE = 10_000e18;
    uint256 internal constant RESERVE_QUOTE = 10_000e18;

    function run()
        external
        returns (address leaderboard, address market, address factory)
    {
        vm.startBroadcast();

        // 1. Leaderboard
        Leaderboard lb = new Leaderboard();

        // 2. SimpleMarket (câblé au Leaderboard)
        SimpleMarket mkt = new SimpleMarket(address(lb), RESERVE_BASE, RESERVE_QUOTE);

        // 3. AgentDeployer (porte le bytecode des enfants) puis AgentFactory.
        AgentDeployer dep = new AgentDeployer();
        AgentFactory fac = new AgentFactory(address(mkt), address(lb), address(dep));

        // 4. Câblage des autorisations.
        mkt.setFactory(address(fac));
        lb.setMarket(address(mkt));
        lb.setScoreUpdater(address(mkt));
        lb.setRegistrar(address(fac));

        vm.stopBroadcast();

        leaderboard = address(lb);
        market = address(mkt);
        factory = address(fac);

        // Affichage pour report dans frontend/.env.local (NEXT_PUBLIC_*).
        console2.log("=== Ritual Trading Arena deploye (Chain ID 1979) ===");
        console2.log("Leaderboard  :", leaderboard);
        console2.log("SimpleMarket :", market);
        console2.log("AgentFactory :", factory);
        console2.log("");
        console2.log("Renseigner frontend/.env.local :");
        console2.log("NEXT_PUBLIC_LEADERBOARD=", leaderboard);
        console2.log("NEXT_PUBLIC_SIMPLE_MARKET=", market);
        console2.log("NEXT_PUBLIC_AGENT_FACTORY=", factory);
    }
}
