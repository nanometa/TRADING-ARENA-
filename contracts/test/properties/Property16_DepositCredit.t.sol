// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AgentWallet} from "../../src/AgentWallet.sol";
import {RitualAddresses} from "../../src/RitualAddresses.sol";

/// Feature: ritual-trading-arena, Property 16: Le dépôt crédite exactement le montant déposé.
///
/// Pour tout montant en RITUAL strictement positif déposé dans un Agent_Wallet, le
/// crédit du TradingAgent correspondant augmente exactement du montant déposé.
///
/// Validates: Requirements 2.2
contract Property16_DepositCredit is Test {
    address internal ownerAddr = address(0xA11CE);
    address internal agentAddr = address(0xA9E47);

    function setUp() public {
        // Mock du RitualWallet système : deposit(uint256) payable ne fait rien.
        vm.mockCall(
            RitualAddresses.RITUAL_WALLET,
            abi.encodeWithSignature("deposit(uint256)"),
            abi.encode()
        );
    }

    function testFuzz_depositCreditsExactly(uint256 amount, uint256 lockDuration) public {
        amount = bound(amount, 1, 1_000_000 ether); // strictement positif
        lockDuration = bound(lockDuration, 1, 1_000_000);

        AgentWallet w = new AgentWallet(ownerAddr, agentAddr, 1);

        uint256 before = w.totalDeposited();

        vm.deal(ownerAddr, amount);
        vm.prank(ownerAddr);
        w.deposit{value: amount}(lockDuration);

        // Crédit exact du montant déposé (Req 2.2).
        assertEq(w.totalDeposited(), before + amount, "credit = montant depose");
    }

    function test_zeroDepositReverts() public {
        AgentWallet w = new AgentWallet(ownerAddr, agentAddr, 1);
        vm.prank(ownerAddr);
        vm.expectRevert(AgentWallet.ZeroDeposit.selector);
        w.deposit{value: 0}(100);
    }
}
