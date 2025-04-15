local util = {}

local select = select  -- 转为upvalue

local ESC_LBRACE = '\254\255LBRACE\255\254'  -- 转义“{”
local ESC_RBRACE = '\254\255RBRACE\255\254'  -- 转义“}”

---模板字符串替换，将{key}替换为replacer[key]或replacer(key)的值。
---
---转义：“{{”将被视为“{”，而“}}”将被视为“}”。
---
---示例：
---```lua
---fmt('Hello, {name}!', { name = 'Lua' }) --> 'Hello, Lua!'
---fmt('Hello, {name}!', function (key)
---   if key == 'name' then
---       return 'Lua'
---   end
---end)  --> 'Hello, Lua!'
---fmr('Hello, {{name}}', { name = 'Lua' })  --> 'Hello, {name}!'，因为“{{”和“}}”是“{”和“}”的转义
---fmr('Hello, {name}', { name = false })  --> 'Hello, {name}!'，因为false代表不替换
---```
---
---@param template string
---@param replacer (fun(key: string): string | number | false | nil) | { [string]: string | number | false | nil } 替换器，用法同string.gsub的第二个参数
---@param on_missing? string | number | (fun(key: string): string | number | false) 当replacer输出nil时触发on_missing：若on_missing是字符串或数字，则用该值替换{key}；若on_missing是函数，则用on_missing(key)替换{key}；若未传入on_missing，则抛出错误
---@return string
function util.fmt(template, replacer, on_missing)
	local get_replacement = type(replacer) == 'function' and replacer or function (key) return replacer[key] end
	local get_fallback = type(on_missing) == 'function' and on_missing or function () return on_missing end

	local function replace_placeholder(placeholder)
		return placeholder:gsub('^.%s*(.-)%s*.$', function (key)
			local replacement = get_replacement(key)
			if replacement ~= nil then return replacement end

			---@diagnostic disable-next-line: cast-local-type
			replacement = get_fallback(key)
			if replacement ~= nil then return replacement end

			error('string interpolation: missing replacement for '..placeholder, 6)
		end)
	end

	local s = template
		:gsub('{{', ESC_LBRACE)  -- 处理“{{”转义
		:gsub('}}', ESC_RBRACE)  -- 处理“}}”转义
		:gsub('%b{}', replace_placeholder)
		:gsub(ESC_LBRACE, '{')
		:gsub(ESC_RBRACE, '}')
	return s
end

function util.Formatter(template, on_missing)
	return function (replacer, ...)
		if select('#', ...) > 0 then
			return util.fmt(template, replacer, ...)
		end
		return util.fmt(template, replacer, on_missing)
	end
end

return util
