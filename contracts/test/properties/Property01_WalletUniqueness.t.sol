// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AgentFactory} from "../../src/AgentFactory.sol";
import {AgentDeployer} from "../../src/AgentDeployer.sol";
import {SimpleMarket} from "../../src/SimpleMarket.sol";
import {Leaderboard} from "../../src/Leaderboard.sol";
import {AgentRecord} from "../../src/interfaces/IArena.sol";
import {Strategy} from "../../src/interfaces/IRitualSystem.sol";

/// Feature: ritual-trading-arena, Property 1: Unicité des wallets et adresses
/// expéditrices par agent.
///
/// Pour toute séquence de créations d'agents, les adresses des TradingAgent et de
/// leurs AgentWallet associés sont deux à deux distinctes ; aucun wallet ni
/// adresse expéditrice n'est partagé entre deux agents.
///
/// Validates: Requirements 1.2, 2.1
contract Property01_WalletUniqueness is Test {
    AgentFactory internal factory;
    SimpleMarket internal market;
    Leaderboard internal lb;

    function setUp() public {
        lb = new Leaderboard();
        market = new SimpleMarket(address(lb), 1_000_000e18, 1_000_000e18);
        factory = new AgentFactory(address(market), address(lb), address(new AgentDeployer()));

        // Câblage des autorisations.
        market.setFactory(address(factory));
        lb.setMarket(address(market));
        lb.setScoreUpdater(address(market));
        lb.setRegistrar(address(factory));
    }

    function testFuzz_walletsAndAgentsAreUnique(uint8 count, uint256 seed) public {
        uint256 n = bound(count, 2, 8);

        address[] memory agents = new address[](n);
        address[] memory wallets = new address[](n);

        for (uint256 i = 0; i < n; i++) {
            Strategy s = (uint256(keccak256(abi.encode(seed, i))) % 2 == 0)
                ? Strategy.TREND_FOLLOWING
                : Strategy.MEAN_REVERSION;
            (uint256 agentId, address agent) = factory.createAgent(s, 1_000e18);
            AgentRecord memory rec = factory.getAgent(agentId);
            agents[i] = agent;
            wallets[i] = rec.wallet;

            // Agent et wallet sont des adresses non nulles et différentes l'une de l'autre.
            assertTrue(agent != address(0), "agent non nul");
            assertTrue(rec.wallet != address(0), "wallet non nul");
            assertTrue(agent != rec.wallet, "agent != wallet");
        }

        // Toutes les adresses d'agents distinctes deux à deux ; idem pour les wallets ;
        // et aucun chevauchement agent/wallet.
        for (uint256 i = 0; i < n; i++) {
            for (uint256 j = i + 1; j < n; j++) {
                assertTrue(agents[i] != agents[j], "agents distincts");
                assertTrue(wallets[i] != wallets[j], "wallets distincts");
            }
            for (uint256 k = 0; k < n; k++) {
                assertTrue(agents[i] != wallets[k], "aucun chevauchement agent/wallet");
            }
        }
    }
}
