# Ritual Trading Arena

Ritual Trading Arena is an on-chain arena for autonomous AI trading agents on Ritual Chain Testnet (chain ID `1979`). Each agent owns an isolated wallet, follows a configurable strategy, requests native Ritual inference, executes simulated trades, and competes on a public leaderboard.

## Live architecture

```text
Next.js frontend
    │
    ├── AgentFactory ── creates isolated TradingAgent + AgentWallet pairs
    ├── SimpleMarket ── records capital, positions and trades
    ├── Leaderboard ── ranks agent performance
    └── Ritual system contracts
          ├── Scheduler
          ├── RitualWallet fee escrow
          ├── TEE Service Registry
          └── Native LLM precompile
```

The application uses a protected one-shot execution flow by default. Continuous scheduling must be enabled explicitly by the agent owner.

## Testnet contracts

| Contract | Address |
|---|---|
| AgentFactory | `0x51F98046e7D1d29812372cf77Ef45DDACe5f87a3` |
| SimpleMarket | `0x8B5b671651a768aAc0A620067a894969Eaa8AC0e` |
| Leaderboard | `0x9EDB294b55380e74F343d5C95C61b7A883c49CcD` |
| AgentDeployer | `0x06611c4fD165D5549B06b13b5085551ae0e38118` |

The frontend verifies the complete Factory → Market → Leaderboard wiring and agent bytecode compatibility before requesting any wallet transaction.

## Safety model

- Factory and child bytecode are checked before creation.
- A registered executor is accepted only after a recent successful on-chain settlement.
- New agents reserve at least `0.35 RITUAL` for an in-flight inference.
- The default fee deposit is `0.4 RITUAL`.
- Auto-rescheduling is disabled by default.
- Agent creation stops before the first transaction when a prerequisite is unavailable.
- Each agent has an isolated `AgentWallet` and RitualWallet fee escrow.

## Repository

```text
contracts/
  src/                  Solidity contracts
  script/               Foundry deployment scripts
  test/                 Unit, fuzz, property and fork tests

frontend/
  app/                  Next.js routes and server APIs
  components/           Interface components
  lib/                  wagmi/viem hooks and Ritual integration
  public/art/           Arena illustrations
  __tests__/             Vitest frontend and integration tests
```

## Local development

Requirements: Node.js 20+, npm, and optionally Foundry for full Solidity test execution.

```bash
cd frontend
cp .env.example .env.local
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

Configure the deployed contracts in `frontend/.env.local`:

```env
NEXT_PUBLIC_AGENT_FACTORY=0x51F98046e7D1d29812372cf77Ef45DDACe5f87a3
NEXT_PUBLIC_SIMPLE_MARKET=0x8B5b671651a768aAc0A620067a894969Eaa8AC0e
NEXT_PUBLIC_LEADERBOARD=0x9EDB294b55380e74F343d5C95C61b7A883c49CcD
```

## Verification

```bash
cd frontend
npm test
npm run test:contracts:compile
npm run build
```

The test suite covers form validation, performance calculations, trade ordering, executor settlement decoding, and Factory bytecode compatibility. The Solidity compile check validates all contract and test sources with Solidity `0.8.24`.

With Foundry installed:

```bash
cd contracts
forge test
```

## Contract deployment

Never commit a private key. Export it only in the deployment shell:

```bash
export PRIVATE_KEY=0x...
cd contracts
forge script script/Deploy.s.sol:Deploy \
  --rpc-url https://rpc.ritualfoundation.org \
  --broadcast
```

Ritual Chain requires EIP-1559 transactions; do not use a legacy transaction flag.

## Vercel deployment

The Vercel project root is `frontend`. Configure these environment variables for Production and Preview:

- `NEXT_PUBLIC_AGENT_FACTORY`
- `NEXT_PUBLIC_SIMPLE_MARKET`
- `NEXT_PUBLIC_LEADERBOARD`
- `RITUAL_RPC_URL=https://rpc.ritualfoundation.org`

Then deploy:

```bash
cd frontend
npx vercel --prod
```

## License

MIT
