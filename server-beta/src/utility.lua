local tableSort    = table.sort
local stringRep    = string.rep
local tableConcat  = table.concat
local tostring     = tostring
local type         = type
local pairs        = pairs
local ipairs       = ipairs
local next         = next
local rawset       = rawset
local move         = table.move
local setmetatable = setmetatable
local mathType     = math.type
local mathCeil     = math.ceil
local getmetatable = getmetatable
local mathAbs      = math.abs
local ioOpen       = io.open

_ENV = nil

local function formatNumber(n)
    local str = ('%.10f'):format(n)
    str = str:gsub('%.?0*$', '')
    return str
end

local function isInteger(n)
    if mathType then
        return mathType(n) == 'integer'
    else
        return type(n) == 'number' and n % 1 == 0
    end
end

local TAB = setmetatable({}, { __index = function (self, n)
    self[n] = stringRep('    ', n)
    return self[n]
end})

local RESERVED = {
    ['and']      = true,
    ['break']    = true,
    ['do']       = true,
    ['else']     = true,
    ['elseif']   = true,
    ['end']      = true,
    ['false']    = true,
    ['for']      = true,
    ['function'] = true,
    ['goto']     = true,
    ['if']       = true,
    ['in']       = true,
    ['local']    = true,
    ['nil']      = true,
    ['not']      = true,
    ['or']       = true,
    ['repeat']   = true,
    ['return']   = true,
    ['then']     = true,
    ['true']     = true,
    ['until']    = true,
    ['while']    = true,
}

local m = {}

--- 打印表的结构
---@param tbl table
---@param option table {optional = 'self'}
---@return string
function m.dump(tbl, option)
    if not option then
        option = {}
    end
    if type(tbl) ~= 'table' then
        return ('%s'):format(tbl)
    end
    local lines = {}
    local mark = {}
    lines[#lines+1] = '{'
    local function unpack(tbl, tab)
        if mark[tbl] and mark[tbl] > 0 then
            lines[#lines+1] = TAB[tab+1] .. '"<Loop>"'
            return
        end
        mark[tbl] = (mark[tbl] or 0) + 1
        local keys = {}
        local keymap = {}
        local integerFormat = '[%d]'
        local alignment = 0
        if #tbl >= 10 then
            local width = #tostring(#tbl)
            integerFormat = ('[%%0%dd]'):format(mathCeil(width))
        end
        for key in pairs(tbl) do
            if type(key) == 'string' then
                if not key:match('^[%a_][%w_]*$')
                or RESERVED[key]
                or option['longStringKey']
                then
                    keymap[key] = ('[%q]'):format(key)
                else
                    keymap[key] = ('%s'):format(key)
                end
            elseif isInteger(key) then
                keymap[key] = integerFormat:format(key)
            else
                keymap[key] = ('["<%s>"]'):format(tostring(key))
            end
            keys[#keys+1] = key
            if option['alignment'] then
                if #keymap[key] > alignment then
                    alignment = #keymap[key]
                end
            end
        end
        local mt = getmetatable(tbl)
        if not mt or not mt.__pairs then
            if option['sorter'] then
                option['sorter'](keys, keymap)
            else
                tableSort(keys, function (a, b)
                    return keymap[a] < keymap[b]
                end)
            end
        end
        for _, key in ipairs(keys) do
            local keyWord = keymap[key]
            if option['noArrayKey']
                and isInteger(key)
                and key <= #tbl
            then
                keyWord = ''
            else
                if #keyWord < alignment then
                    keyWord = keyWord .. (' '):rep(alignment - #keyWord) .. ' = '
                else
                    keyWord = keyWord .. ' = '
                end
            end
            local value = tbl[key]
            local tp = type(value)
            if tp == 'table' then
                lines[#lines+1] = ('%s%s{'):format(TAB[tab+1], keyWord)
                unpack(value, tab+1)
                lines[#lines+1] = ('%s},'):format(TAB[tab+1])
            elseif tp == 'string' then
                lines[#lines+1] = ('%s%s%q,'):format(TAB[tab+1], keyWord, value)
            elseif tp == 'number' then
                lines[#lines+1] = ('%s%s%s,'):format(TAB[tab+1], keyWord, formatNumber(value))
            elseif tp == 'nil' then
            else
                lines[#lines+1] = ('%s%s%s,'):format(TAB[tab+1], keyWord, tostring(value))
            end
        end
        mark[tbl] = mark[tbl] - 1
    end
    unpack(tbl, 0)
    lines[#lines+1] = '}'
    return tableConcat(lines, '\r\n')
end

--- 递归判断A与B是否相等
---@param a any
---@param b any
---@return boolean
function m.equal(a, b)
    local tp1 = type(a)
    local tp2 = type(b)
    if tp1 ~= tp2 then
        return false
    end
    if tp1 == 'table' then
        local mark = {}
        for k, v in pairs(a) do
            mark[k] = true
            local res = m.equal(v, b[k])
            if not res then
                return false
            end
        end
        for k in pairs(b) do
            if not mark[k] then
                return false
            end
        end
        return true
    elseif tp1 == 'number' then
        return mathAbs(a - b) <= 1e-10
    else
        return a == b
    end
end

local function sortTable(tbl)
    if not tbl then
        tbl = {}
    end
    local mt = {}
    local keys = {}
    local mark = {}
    local n = 0
    for key in next, tbl do
        n=n+1;keys[n] = key
        mark[key] = true
    end
    tableSort(keys)
    function mt:__newindex(key, value)
        rawset(self, key, value)
        n=n+1;keys[n] = key
        mark[key] = true
        if type(value) == 'table' then
            sortTable(value)
        end
    end
    function mt:__pairs()
        local list = {}
        local m = 0
        for key in next, self do
            if not mark[key] then
                m=m+1;list[m] = key
            end
        end
        if m > 0 then
            move(keys, 1, n, m+1)
            tableSort(list)
            for i = 1, m do
                local key = list[i]
                keys[i] = key
                mark[key] = true
            end
            n = n + m
        end
        local i = 0
        return function ()
            i = i + 1
            local key = keys[i]
            return key, self[key]
        end
    end

    return setmetatable(tbl, mt)
end

--- 创建一个有序表
---@param tbl table {optional = 'self'}
---@return table
function m.container(tbl)
    return sortTable(tbl)
end

--- 读取文件
---@param path string
function m.loadFile(path)
    local f, e = ioOpen(path, 'rb')
    if not f then
        return nil, e
    end
    if f:read(3) ~= '\xEF\xBB\xBF' then
        f:seek("set")
    end
    local buf = f:read 'a'
    f:close()
    return buf
end

--- 写入文件
---@param path string
---@param content string
function m.saveFile(path, content)
    local f, e = ioOpen(path, "wb")

    if f then
        f:write(content)
        f:close()
        return true
    else
        return false, e
    end
end

--- 计数器
---@param init integer {optional = 'after'}
---@param step integer {optional = 'after'}
---@return fun():integer
function m.counter(init, step)
    if not step then
        step = 1
    end
    local current = init and (init - 1) or -1
    return function ()
        current = current + step
        return current
    end
end

--- 排序后遍历
---@param t table
function m.sortPairs(t)
    local keys = {}
    for k in pairs(t) do
        keys[#keys+1] = k
    end
    tableSort(keys)
    local i = 0
    return function ()
        i = i + 1
        local k = keys[i]
        return k, t[k]
    end
end

--- 深拷贝（不处理元表）
---@param source table
---@param target table {optional = 'self'}
function m.deepCopy(source, target)
    local mark = {}
    local function copy(a, b)
        if type(a) ~= 'table' then
            return a
        end
        if mark[a] then
            return mark[a]
        end
        if not b then
            b = {}
        end
        mark[a] = b
        for k, v in pairs(a) do
            b[copy(k)] = copy(v)
        end
        return b
    end
    return copy(source, target)
end

return m
