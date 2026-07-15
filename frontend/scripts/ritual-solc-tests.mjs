import fs from "node:fs";
import path from "node:path";
import solc from "solc";

const contractsRoot = path.resolve(process.cwd(), "..", "contracts");

function collect(directory, sources = {}) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) collect(fullPath, sources);
    if (entry.isFile() && entry.name.endsWith(".sol")) {
      const sourceName = path.relative(contractsRoot, fullPath).replaceAll("\\", "/");
      sources[sourceName] = { content: fs.readFileSync(fullPath, "utf8") };
    }
  }
  return sources;
}

const sources = collect(path.join(contractsRoot, "src"));
collect(path.join(contractsRoot, "test"), sources);

const input = {
  language: "Solidity",
  sources,
  settings: {
    optimizer: { enabled: true, runs: 1 },
    viaIR: true,
    outputSelection: { "*": { "*": ["abi"] } },
  },
};

const output = JSON.parse(
  solc.compile(JSON.stringify(input), {
    import(importPath) {
      const candidates = [
        path.join(contractsRoot, importPath),
        path.join(
          contractsRoot,
          "lib",
          "forge-std",
          "src",
          importPath.replace(/^forge-std\//, ""),
        ),
      ];
      const resolved = candidates.find((candidate) => fs.existsSync(candidate));
      return resolved
        ? { contents: fs.readFileSync(resolved, "utf8") }
        : { error: `Import not found: ${importPath}` };
    },
  }),
);

const diagnostics = output.errors ?? [];
const errors = diagnostics.filter((item) => item.severity === "error");
if (errors.length) {
  throw new Error(errors.map((item) => item.formattedMessage).join("\n"));
}

console.log(`SOLIDITY_TEST_COMPILE_OK sources=${Object.keys(sources).length}`);
