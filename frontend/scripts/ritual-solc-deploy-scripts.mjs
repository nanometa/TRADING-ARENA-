import fs from "node:fs";
import path from "node:path";
import solc from "solc";

const contractsRoot = path.resolve(process.cwd(), "..", "contracts");

function collect(directory, sources = {}) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) collect(fullPath, sources);
    if (entry.isFile() && entry.name.endsWith(".sol")) {
      const name = path.relative(contractsRoot, fullPath).replaceAll("\\", "/");
      sources[name] = { content: fs.readFileSync(fullPath, "utf8") };
    }
  }
  return sources;
}

const sources = collect(path.join(contractsRoot, "src"));
collect(path.join(contractsRoot, "lib", "forge-std", "src"), sources);

for (const name of ["Deploy.s.sol", "SeedDemoAgents.s.sol"]) {
  const fullPath = path.join(contractsRoot, "script", name);
  sources[`script/${name}`] = { content: fs.readFileSync(fullPath, "utf8") };
}

const output = JSON.parse(
  solc.compile(
    JSON.stringify({
      language: "Solidity",
      sources,
      settings: {
        remappings: ["forge-std/=lib/forge-std/src/"],
        optimizer: { enabled: true, runs: 1 },
        viaIR: true,
        outputSelection: { "*": { "*": ["abi", "evm.bytecode.object"] } },
      },
    }),
  ),
);

const errors = (output.errors ?? []).filter((item) => item.severity === "error");
if (errors.length > 0) {
  throw new Error(errors.map((item) => item.formattedMessage).join("\n"));
}

for (const [source, name] of [
  ["script/Deploy.s.sol", "Deploy"],
  ["script/SeedDemoAgents.s.sol", "SeedDemoAgents"],
]) {
  if (!output.contracts?.[source]?.[name]?.evm?.bytecode?.object) {
    throw new Error(`Missing ${source}:${name}`);
  }
  console.log(`${name}: OK`);
}

console.log(`warnings=${(output.errors ?? []).filter((item) => item.severity !== "error").length}`);
console.log("SCRIPT_COMPILE_OK");
