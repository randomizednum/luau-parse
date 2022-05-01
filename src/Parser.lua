-- OptimisticSIde
-- 5/1/2022
-- Luau parser

-- luacheck: push globals script
local AstNode = require(_VERSION == "Luau" and script.Parent.AstNode or "./AstNode.lua")
local Token = require(_VERSION == "Luau" and script.Parent.Token or "./Token.lua")
-- luacheck: pop

local Parser = {}
Parser.__index = Parser

function Parser.new(tokens)
	local self = {}
	setmetatable(self, Parser)

	self._tokens = tokens
	self._token = self._tokens[1]
	self._position = 1

	return self
end

function Parser.is(object)
	return type(object) == "table" and getmetatable(object) == Parser
end

--[[
	Determines whether a statement is the last statement of a block.

	This saves us time because we won't have to parse statements after
	it.
]]
function Parser.isLastStat(stat)
	return stat.kind == AstNode.Kind.Break
		or stat.Kind == AstNode.Kind.Continue
		or stat.kind == AstNode.Kind.Break
		or stat.kind == AstNode.Kind.Return
end

--[[
	Throws an error generated by the parser.

	Note that this can be overriden by the user (since it's retrieved
	through the __index metamethod).
]]
-- luacheck: ignore self
function Parser:_error(formatString, ...)
	error(formatString:format(...))
end

--[[
	Accepts a token if valid, and returns nil otherwise.
]]
function Parser:_accept(tokenKind)
	local token = self._token
	if token and token.kind == tokenKind then
		self:_advance()
		return token
	end
end

--[[
	Expects to read a certain type of token. If this token is not found,
	then it will throw a parse-error.
]]
function Parser:_expect(tokenKind)
	local token = self:_accept(tokenKind)
	if not token or token.kind ~= tokenKind then
		self:_error(
			"Expected %s, got %s at %s",
			Token.kindString(tokenKind),
			Token.kindString(token.kind),
			token.position
		)
		return
	end
	return token
end

function Parser:parseStat()
	-- Do-block parser.
	if self:_accept(Token.Kind.Do) then
		local body = self:parseBlock()
		self:_expect(Token.Kind.End)
		return AstNode.new(AstNode.Kind.DoBlock, body)
	end

	-- While-loop parser.
	if self:_accept(Token.Kind.While) then
		local condition = self:parseExpr()
		self:_expect(Token.Kind.Do)

		local body = self:parseBlock()
		self:_expect(Token.Kind.End)

		return AstNode.new(AstNode.Kind.WhileLoop, condition, body)
	end

	-- Repeat-until loop parser.
	-- Essentially the same as the while-loop parser, except it expects
	-- a `until` instead of `do`.
	if self:_accept(Token.Kind.Repeat) then
		local condition = self:parseExpr()
		self:_expect(Token.Kind.Until)

		local body = self:parseBlock()
		self:_expect(Token.Kind.End)

		return AstNode.new(AstNode.Kind.RepeatLoop, condition, body)
	end

	-- If-block parser.
	if self:_accept(Token.Kind.If) then
		local ifCondition = self:parseExpr()
		self:_expect(Token.Kind.Then)

		local thenBlock = self:parseBlock()
		local blocks = { { ifCondition, thenBlock }  }

		while self:_accept(Token.Kind.ElseIf) do
			local elseIfCondition = self:parseExpr()
			self:_expect(Token.Kind.Then)
			table.insert(blocks, { elseIfCondition, self:parseBlock() })
		end

		if self:_accept(Token.Kind.Else) then
			table.insert(blocks, self:parseBlock())
		end

		self:_accept(Token.Kind.End)
		-- Each block is in the block array (in order)
		-- Else-if and if statements are stored as an array containing
		-- their condition and block. Then statements are just stored
		-- as just their block.
		return AstNode.new(AstNode.Kind.IfStat, table.unpack(blocks))
	end
end

function Parser:parseBlock()
	local stats = {}
	local stat

	repeat
		stat = self:parseStat()
		table.insert(stats, stat)
		self:_accept(Token.Kind.SEMI)
	until not self:isLastStat(stat)

	return AstNode.new(AstNode.Kind.Block, table.unpack(stats))
end

--[[
	Main parsing routine. Parses a chunk of luau code.
--]]
function Parser:parseChunk()
	return self:parseBlock()
end

return Parser
