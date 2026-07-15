import fs from "node:fs";
import path from "node:path";
import solc from "solc";

const contractsRoot = path.resolve(process.cwd(), "..", "contracts");
const srcRoot = path.join(contractsRoot, "src");

function collectSoliditySources(directory, sources = {}) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      collectSoliditySources(fullPath, sources);
    } else if (entry.isFile() && entry.name.endsWith(".sol")) {
      const sourceName = path.relative(contractsRoot, fullPath).replaceAll("\\", "/");
      sources[sourceName] = { content: fs.readFileSync(fullPath, "utf8") };
    }
  }
  return sources;
}

export function compileRitualContracts() {
  const input = {
    language: "Solidity",
    sources: collectSoliditySources(srcRoot),
    settings: {
      optimizer: { enabled: true, runs: 1 },
      viaIR: true,
      outputSelection: {
        "*": {
          "*": ["abi", "evm.bytecode.object", "evm.deployedBytecode.object"],
        },
      },
    },
  };

  const output = JSON.parse(solc.compile(JSON.stringify(input)));
  const diagnostics = output.errors ?? [];
  const errors = diagnostics.filter((item) => item.severity === "error");
  if (errors.length > 0) {
    throw new Error(errors.map((item) => item.formattedMessage).join("\n"));
  }

  return {
    output,
    warnings: diagnostics.filter((item) => item.severity !== "error"),
    contract(source, name) {
      const artifact = output.contracts?.[source]?.[name];
      if (!artifact?.evm?.bytecode?.object) {
        throw new Error(`Missing compiled artifact ${source}:${name}`);
      }
      return {
        abi: artifact.abi,
        bytecode: `0x${artifact.evm.bytecode.object}`,
        deployedBytecode: `0x${artifact.evm.deployedBytecode.object}`,
      };
    },
  };
}

export function byteLength(hex) {
  return (hex.length - 2) / 2;
}
