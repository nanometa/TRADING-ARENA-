import { describe, expect, it } from "vitest";
import { toFunctionSelector, type Hex } from "viem";
import {
  REQUIRED_AGENT_FUNCTIONS,
  REQUIRED_FACTORY_FUNCTIONS,
  bytecodeSupports,
  classifyFactoryGeneration,
} from "../lib/factoryCompatibility";

function fakeBytecode(signatures: readonly string[]): Hex {
  return `0x60${signatures.map((signature) => toFunctionSelector(signature).slice(2)).join("61")}` as Hex;
}

const FACTORY_CODE = fakeBytecode(REQUIRED_FACTORY_FUNCTIONS);
const DEPLOYER_CODE = fakeBytecode(REQUIRED_AGENT_FUNCTIONS);

describe("Ritual Arena Factory compatibility", () => {
  it("accepts the deployed pre-version Factory when its bytecode is compatible", () => {
    expect(classifyFactoryGeneration(null, FACTORY_CODE, DEPLOYER_CODE)).toBe(
      "legacy-compatible",
    );
  });

  it("recognizes Factory v2", () => {
    expect(classifyFactoryGeneration(2n, FACTORY_CODE, DEPLOYER_CODE)).toBe("v2");
  });

  it("rejects a deployer missing a required safety function", () => {
    const incomplete = fakeBytecode(REQUIRED_AGENT_FUNCTIONS.slice(0, -1));
    expect(classifyFactoryGeneration(null, FACTORY_CODE, incomplete)).toBe("unsupported");
  });

  it("does not treat empty bytecode as compatible", () => {
    expect(bytecodeSupports("0x", REQUIRED_FACTORY_FUNCTIONS)).toBe(false);
  });
});
