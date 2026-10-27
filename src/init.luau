--!strict

local Properties = require(script.Properties)
local lineBreaks = require(script.LineBreak)
export type Break = { position: number, required: boolean }

return { version = Properties.version, lineBreakProperty = Properties.get, lineBreaks = lineBreaks }
