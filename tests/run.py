#!/usr/bin/env python3
"""Runs tests/shared.spec.luau against src/shared with the standalone Luau CLI.

Shared modules only touch a few Roblox types (Color3, Enum, Vector3, Random), so this bundles
them with small stubs instead of needing Studio. Usage: python3 tests/run.py [path/to/luau]
"""

import pathlib
import re
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHARED = ROOT / "src" / "shared"
# Net talks to game services and is covered by the in-Studio playtest instead.
SKIP = {"Net"}

PRELUDE = r"""
local Color3 = {}
function Color3.fromRGB(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end
function Color3.new(r, g, b) return { R = r, G = g, B = b } end
local Vector3 = {}
function Vector3.new(x, y, z) return { X = x, Y = y, Z = z } end
local Enum = setmetatable({}, { __index = function(_, group)
	return setmetatable({}, { __index = function(_, item) return group .. "." .. item end })
end })
local Random = {}
function Random.new(seed)
	if seed then math.randomseed(seed) end
	return {
		NextNumber = function(_, lo, hi)
			lo, hi = lo or 0, hi or 1
			return lo + math.random() * (hi - lo)
		end,
		NextInteger = function(_, lo, hi) return math.random(lo, hi) end,
	}
end

local __modules = {}
local __cache = {}
local __parent = setmetatable({}, { __index = function(_, name) return { __module = name } end })
local function require(ref)
	local name = ref.__module
	if __cache[name] == nil then
		__cache[name] = __modules[name]({ Parent = __parent })
	end
	return __cache[name]
end
local function shared(name) return require({ __module = name }) end
"""


def main() -> int:
    luau = sys.argv[1] if len(sys.argv) > 1 else "luau"
    parts = [PRELUDE]
    for path in sorted(SHARED.glob("*.luau")):
        if path.stem in SKIP:
            continue
        body = re.sub(r"^export type", "type", path.read_text(), flags=re.MULTILINE)
        parts.append(f'__modules["{path.stem}"] = function(script)\n{body}\nend\n')
    parts.append((ROOT / "tests" / "shared.spec.luau").read_text())
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as bundle:
        bundle.write("\n".join(parts))
    return subprocess.run([luau, bundle.name]).returncode


if __name__ == "__main__":
    sys.exit(main())
