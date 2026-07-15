// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ISimpleMarket} from "../../src/interfaces/IArena.sol";

/// @title MockMarket
/// @notice Mock du SimpleMarket pour tester le Leaderboard : capital/position/prix
///         sont fixés directement par le test, sans logique d'AMM.
contract MockMarket is ISimpleMarket {
    uint256 public price = 1e18;
    mapping(uint256 => uint256) public capital;
    mapping(uint256 => uint256) public position;

    function setPrice(uint256 p) external {
        price = p;
    }

    function setAgent(uint256 agentId, uint256 cap, uint256 pos) external {
        capital[agentId] = cap;
        position[agentId] = pos;
    }

    // ── ISimpleMarket ──
    function buy(uint256, uint256) external pure override returns (uint256) {
        return 0;
    }

    function sell(uint256, uint256) external pure override returns (uint256) {
        return 0;
    }

    function currentPrice() external view override returns (uint256) {
        return price;
    }

    function capitalOf(uint256 agentId) external view override returns (uint256) {
        return capital[agentId];
    }

    function positionOf(uint256 agentId) external view override returns (uint256) {
        return position[agentId];
    }
}
