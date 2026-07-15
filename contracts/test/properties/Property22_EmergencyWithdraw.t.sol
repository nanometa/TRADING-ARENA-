// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AgentWallet} from "../../src/AgentWallet.sol";

/// Feature: ritual-trading-arena, Property 22: Le retrait d'urgence conserve et
/// transfère le capital non engagé.
///
/// Pour tout montant de capital disponible non engagé, le retrait d'urgence
/// transfère exactement ce montant vers l'adresse de l'owner, ramenant le capital
/// non engagé de l'agent à zéro.
///
/// Validates: Requirements 9.6
contract Property22_EmergencyWithdraw is Test {
    address internal ownerAddr = address(0xA11CE);
    address internal agentAddr = address(0xA9E47);

    function testFuzz_emergencyWithdrawTransfersExactly(uint256 amount) public {
        amount = bound(amount, 0, 1_000_000 ether);

        AgentWallet w = new AgentWallet(ownerAddr, agentAddr, 1);

        // Approvisionner le wallet en capital non engagé (solde natif).
        vm.deal(address(w), amount);
        uint256 ownerBefore = ownerAddr.balance;

        // Retrait d'urgence par l'owner.
        vm.prank(ownerAddr);
        w.emergencyWithdraw();

        // Transfert exact + solde du wallet ramené à zéro (Req 9.6).
        assertEq(ownerAddr.balance, ownerBefore + amount, "owner credite du montant exact");
        assertEq(address(w).balance, 0, "capital non engage ramene a zero");
    }
}
