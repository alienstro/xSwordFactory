-- Runs all unit tests. Use: lune run tests/run
local process = require("@lune/process")
local Harness = require("./Harness")

require("./Config.spec")
require("./Odds.spec")
require("./Sword.spec")

process.exit(if Harness.summary() then 0 else 1)
