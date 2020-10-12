--
-- Licensed to the Apache Software Foundation (ASF) under one or more
-- contributor license agreements.  See the NOTICE file distributed with
-- this work for additional information regarding copyright ownership.
-- The ASF licenses this file to You under the Apache License, Version 2.0
-- (the "License"); you may not use this file except in compliance with
-- the License.  You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
local _M = {}

-- for pure Lua
local split = function(str, delimiter)
    local t = {}
    for substr in string.gmatch(str, "[^".. delimiter.. "]*") do
        if substr ~= nil and string.len(substr) > 0 then
            table.insert(t,substr)
        end
    end
    return t
end

-- 字符串替换【不执行模式匹配】
-- s       源字符串
-- pattern 匹配字符串
-- repl    替换字符串
--
-- 成功返回替换后的字符串，失败返回源字符串
local replace = function(s, pattern, repl)
    local i,j = string.find(s, pattern, 1, true)
    if i and j then
        local ret = {}
        local start = 1
        while i and j do
            table.insert(ret, string.sub(s, start, i - 1))
            table.insert(ret, repl)
            start = j + 1
            i,j = string.find(s, pattern, start, true)
        end
        table.insert(ret, string.sub(s, start))
        return table.concat(ret)
    end
    return s
end

local timestamp = function()
    local _, b = math.modf(os.clock())
    if b==0 then
        b='000'
    else
        b=tostring(b):sub(3,5)
    end

    return os.time() * 1000 + b
end

-- for Nginx Lua
local ok, ngx_re = pcall(require, "ngx.re")
if ok then
    split = ngx_re.split
    timestamp = function()
        return ngx.now() * 1000
    end
end

_M.split = split
_M.timestamp = timestamp
_M.is_ngx_lua = ok

local MAX_SEQ = 10000

local timeSeq = function()
    return ngx.now() * MAX_SEQ + math.random(0, MAX_SEQ)
end

--PROCESS_ID.THREAD_ID.(TIME_MILLIS*10000+Seq)

local newID
 --for Nginx Lua
local ok, uuid = pcall(require, "kong.plugins.trace.resty.jit-uuid")
if ok then
    uuid.seed()
    newID = function()
        return uuid.generate_v4() .. '.' .. ngx.worker.pid() .. '.' .. timeSeq()
    end
else
    local ok, k_utils = pcall(require, "kong.tools.utils")
    if ok then
        newID = function()
            return replace(k_utils.uuid(), "-","") .. '.' .. ngx.worker.pid() .. '.' .. timeSeq()
        end
    end
end

_M.newID = newID

if _M.is_ngx_lua then
    _M.encode_base64 = ngx.encode_base64
    _M.decode_base64 = ngx.decode_base64

else
    local Base64 = require('kong.plugins.trace.dependencies.base64')
    _M.encode_base64 = Base64.encode
    _M.decode_base64 = Base64.decode
end

return _M
