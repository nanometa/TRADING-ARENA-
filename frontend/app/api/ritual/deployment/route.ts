import { NextResponse } from "next/server";
import {
  createPublicClient,
  getAddress,
  http,
  parseAbi,
  zeroAddress,
  type Address,
} from "viem";
import { agentFactoryAbi } from "@/lib/abis";
import { classifyFactoryGeneration } from "@/lib/factoryCompatibility";
import { ADDRESSES, ritualTestnet } from "@/lib/ritual";

export const dynamic = "force-dynamic";
export const revalidate = 0;

const marketWiringAbi = parseAbi(["function factory() view returns (address)"]);
const leaderboardWiringAbi = parseAbi(["function registrar() view returns (address)"]);

function sameAddress(left: Address, right: Address) {
  return left.toLowerCase() === right.toLowerCase();
}

export async function GET() {
  try {
    if (
      ADDRESSES.agentFactory === zeroAddress ||
      ADDRESSES.simpleMarket === zeroAddress ||
      ADDRESSES.leaderboard === zeroAddress
    ) {
      return NextResponse.json(
        { error: "Ritual Arena contract addresses are not configured." },
        { status: 503, headers: { "Cache-Control": "no-store" } },
      );
    }

    const client = createPublicClient({
      chain: ritualTestnet,
      transport: http(process.env.RITUAL_RPC_URL ?? ritualTestnet.rpcUrls.default.http[0]),
    });

    const [latestBlock, factoryCode, marketCode, leaderboardCode] = await Promise.all([
      client.getBlockNumber(),
      client.getCode({ address: ADDRESSES.agentFactory }),
      client.getCode({ address: ADDRESSES.simpleMarket }),
      client.getCode({ address: ADDRESSES.leaderboard }),
    ]);

    if (
      !factoryCode ||
      factoryCode === "0x" ||
      !marketCode ||
      marketCode === "0x" ||
      !leaderboardCode ||
      leaderboardCode === "0x"
    ) {
      return NextResponse.json(
        { error: "One or more configured Ritual Arena contracts are not deployed." },
        { status: 503, headers: { "Cache-Control": "no-store" } },
      );
    }

    const [factoryMarket, factoryLeaderboard, deployer, totalAgents, activeAgents] =
      await Promise.all([
        client.readContract({
          address: ADDRESSES.agentFactory,
          abi: agentFactoryAbi,
          functionName: "market",
        }),
        client.readContract({
          address: ADDRESSES.agentFactory,
          abi: agentFactoryAbi,
          functionName: "leaderboard",
        }),
        client.readContract({
          address: ADDRESSES.agentFactory,
          abi: agentFactoryAbi,
          functionName: "deployer",
        }),
        client.readContract({
          address: ADDRESSES.agentFactory,
          abi: agentFactoryAbi,
          functionName: "totalAgents",
        }),
        client.readContract({
          address: ADDRESSES.agentFactory,
          abi: agentFactoryAbi,
          functionName: "activeAgentCount",
        }),
      ]);

    const [marketFactory, leaderboardRegistrar, deployerCode] = await Promise.all([
      client.readContract({
        address: ADDRESSES.simpleMarket,
        abi: marketWiringAbi,
        functionName: "factory",
      }),
      client.readContract({
        address: ADDRESSES.leaderboard,
        abi: leaderboardWiringAbi,
        functionName: "registrar",
      }),
      client.getCode({ address: deployer }),
    ]);

    let implementationVersion: bigint | null = null;
    try {
      implementationVersion = await client.readContract({
        address: ADDRESSES.agentFactory,
        abi: agentFactoryAbi,
        functionName: "IMPLEMENTATION_VERSION",
      });
    } catch {
      // The latest deployed Kiro Factory predates the explicit version getter.
      // Its actual compatibility is established from the deployed bytecode below.
    }

    const wiringReady =
      sameAddress(getAddress(factoryMarket), getAddress(ADDRESSES.simpleMarket)) &&
      sameAddress(getAddress(factoryLeaderboard), getAddress(ADDRESSES.leaderboard)) &&
      sameAddress(getAddress(marketFactory), getAddress(ADDRESSES.agentFactory)) &&
      sameAddress(getAddress(leaderboardRegistrar), getAddress(ADDRESSES.agentFactory));
    const generation = classifyFactoryGeneration(
      implementationVersion,
      factoryCode,
      deployerCode,
    );
    const ready = wiringReady && generation !== "unsupported";

    return NextResponse.json(
      {
        checkedAtBlock: latestBlock.toString(),
        ready,
        creationReady: ready,
        generation,
        implementationVersion: implementationVersion?.toString() ?? null,
        factory: getAddress(ADDRESSES.agentFactory),
        market: getAddress(ADDRESSES.simpleMarket),
        leaderboard: getAddress(ADDRESSES.leaderboard),
        deployer: getAddress(deployer),
        totalAgents: totalAgents.toString(),
        activeAgents: activeAgents.toString(),
        message: ready
          ? generation === "v2"
            ? "Latest Ritual Arena Factory connected."
            : "Latest deployed Factory connected with frontend safety compatibility."
          : "Ritual Arena contracts are not safely wired for agent creation.",
      },
      { headers: { "Cache-Control": "no-store" } },
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown Ritual RPC error.";
    return NextResponse.json(
      { error: `Ritual deployment check failed: ${message}` },
      { status: 503, headers: { "Cache-Control": "no-store" } },
    );
  }
}
