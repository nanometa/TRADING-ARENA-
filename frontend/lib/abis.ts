/// ABIs minimaux (fragments) des contrats applicatifs utilisés par le frontend.
/// Synchronisés à la main avec les interfaces Solidity (IArena.sol).

export const agentFactoryAbi = [
  {
    type: "function",
    name: "IMPLEMENTATION_VERSION",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "market",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "address" }],
  },
  {
    type: "function",
    name: "leaderboard",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "address" }],
  },
  {
    type: "function",
    name: "deployer",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "address" }],
  },
  {
    type: "function",
    name: "createAgent",
    stateMutability: "nonpayable",
    inputs: [
      { name: "strategy", type: "uint8" },
      { name: "initialCapital", type: "uint256" },
    ],
    outputs: [
      { name: "agentId", type: "uint256" },
      { name: "agent", type: "address" },
    ],
  },
  {
    type: "function",
    name: "listAgents",
    stateMutability: "view",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "tuple[]",
        components: [
          { name: "agent", type: "address" },
          { name: "owner", type: "address" },
          { name: "wallet", type: "address" },
          { name: "strategy", type: "uint8" },
          { name: "status", type: "uint8" },
        ],
      },
    ],
  },
  {
    type: "function",
    name: "activeAgentCount",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "totalAgents",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "event",
    name: "AgentCreated",
    inputs: [
      { name: "agentId", type: "uint256", indexed: true },
      { name: "agent", type: "address", indexed: true },
      { name: "owner", type: "address", indexed: true },
      { name: "strategy", type: "uint8", indexed: false },
    ],
  },
] as const;

export const simpleMarketAbi = [
  {
    type: "function",
    name: "currentPrice",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "capitalOf",
    stateMutability: "view",
    inputs: [{ name: "agentId", type: "uint256" }],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "positionOf",
    stateMutability: "view",
    inputs: [{ name: "agentId", type: "uint256" }],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "event",
    name: "TradeExecuted",
    inputs: [
      { name: "agentId", type: "uint256", indexed: true },
      { name: "orderType", type: "uint8", indexed: false },
      { name: "quantity", type: "uint256", indexed: false },
      { name: "price", type: "uint256", indexed: false },
      { name: "blockNumber", type: "uint256", indexed: false },
    ],
  },
] as const;

export const leaderboardAbi = [
  {
    type: "function",
    name: "ranking",
    stateMutability: "view",
    inputs: [],
    outputs: [
      { name: "agentIds", type: "uint256[]" },
      { name: "scores", type: "uint256[]" },
    ],
  },
  {
    type: "function",
    name: "scoreOf",
    stateMutability: "view",
    inputs: [{ name: "agentId", type: "uint256" }],
    outputs: [{ name: "", type: "uint256" }],
  },
] as const;

/// ABI du TradingAgent : contrôles owner + lectures pour la page détail.
export const tradingAgentAbi = [
  {
    type: "function",
    name: "availableCapital",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "position",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "paused",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "bool" }],
  },
  {
    type: "function",
    name: "callId",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "scheduleFrequency",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint32" }],
  },
  {
    type: "function",
    name: "scheduleNumCalls",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint32" }],
  },
  {
    type: "function",
    name: "scheduleTtl",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint32" }],
  },
  {
    type: "function",
    name: "autoReschedule",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "bool" }],
  },
  {
    type: "function",
    name: "consecutiveLlmErrors",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint8" }],
  },
  {
    type: "function",
    name: "cachedExecutor",
    stateMutability: "view",
    inputs: [{ name: "capability", type: "uint8" }],
    outputs: [{ name: "", type: "address" }],
  },
  {
    type: "function",
    name: "emergencyStopped",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "bool" }],
  },
  {
    type: "function",
    name: "externalPrice",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
  },
  { type: "function", name: "pause", stateMutability: "nonpayable", inputs: [], outputs: [] },
  { type: "function", name: "resume", stateMutability: "nonpayable", inputs: [], outputs: [] },
  {
    type: "function",
    name: "emergencyStop",
    stateMutability: "nonpayable",
    inputs: [],
    outputs: [],
  },
  {
    type: "function",
    name: "emergencyWithdraw",
    stateMutability: "nonpayable",
    inputs: [],
    outputs: [],
  },
  {
    type: "function",
    name: "requestPrice",
    stateMutability: "nonpayable",
    inputs: [],
    outputs: [],
  },
  {
    type: "function",
    name: "setBudgetLimit",
    stateMutability: "nonpayable",
    inputs: [
      { name: "limit", type: "uint256" },
      { name: "windowSeconds", type: "uint256" },
    ],
    outputs: [],
  },
  {
    type: "function",
    name: "activate",
    stateMutability: "nonpayable",
    inputs: [
      { name: "frequency", type: "uint32" },
      { name: "numCalls", type: "uint32" },
      { name: "ttl", type: "uint32" },
    ],
    outputs: [],
  },
  {
    type: "function",
    name: "fundFees",
    stateMutability: "payable",
    inputs: [{ name: "lockDuration", type: "uint256" }],
    outputs: [],
  },
  {
    type: "function",
    name: "withdrawFeeEscrow",
    stateMutability: "nonpayable",
    inputs: [{ name: "amount", type: "uint256" }],
    outputs: [],
  },
  {
    type: "function",
    name: "setExecutor",
    stateMutability: "nonpayable",
    inputs: [
      { name: "capability", type: "uint8" },
      { name: "executor", type: "address" },
    ],
    outputs: [],
  },
  {
    type: "function",
    name: "setEstimatedCallCost",
    stateMutability: "nonpayable",
    inputs: [{ name: "cost", type: "uint256" }],
    outputs: [],
  },
  {
    type: "function",
    name: "setAutoReschedule",
    stateMutability: "nonpayable",
    inputs: [{ name: "enabled", type: "bool" }],
    outputs: [],
  },
] as const;

export const ritualWalletAbi = [
  {
    type: "function",
    name: "balanceOf",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
  },
] as const;

/// Registre officiel des services TEE Ritual. Le frontend le lit juste avant
/// la création pour ne jamais câbler un exécuteur HTTP/LLM devenu obsolète.
export const teeServiceRegistryAbi = [
  {
    type: "function",
    name: "getServicesByCapability",
    stateMutability: "view",
    inputs: [
      { name: "capability", type: "uint8" },
      { name: "checkValidity", type: "bool" },
    ],
    outputs: [
      {
        name: "",
        type: "tuple[]",
        components: [
          {
            name: "node",
            type: "tuple",
            components: [
              { name: "paymentAddress", type: "address" },
              { name: "teeAddress", type: "address" },
              { name: "teeType", type: "uint8" },
              { name: "publicKey", type: "bytes" },
              { name: "endpoint", type: "string" },
              { name: "certPubKeyHash", type: "bytes32" },
              { name: "capability", type: "uint8" },
            ],
          },
          { name: "isValid", type: "bool" },
          { name: "workloadId", type: "bytes32" },
        ],
      },
    ],
  },
] as const;
