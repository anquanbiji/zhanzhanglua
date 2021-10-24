--[[
从规则文件读取配置信息
共享内存 wafconfig  主要保存规则配置信息
]]--
-- 加载自己的配置文件
local config = require "config"
local cjson = require "cjson"

local function read_rule(filename)
    local session = ngx.shared.wafconfig
    if session then 
        session:flush_all()  -- 删除所有项目
        config.my_log(ngx.DEBUG, "read rule file:"..filename)
        file = io.open(filename,"r")
        if file==nil then
            return
        end
        for line in file:lines() do

            if true then 
                line = string.gsub(line,"\r","")
                line = string.gsub(line,"\n","")

                local data = cjson.decode(line)

                local host = 'default'
                local time = 0 
                local stime = 0 
                if data.host ~= nil and #data.host > 0 then 
                    host = data.host 
                end 
                -- 域名为key, 配置为值 存储
                session:set(host,cjson.encode(data),0)

            end 
        end
        file:close()
    end 
end


local function main( ... )
    read_rule(config.rulefile)
end

local status, err = xpcall(main, function() config.my_log(ngx.ERR, debug.traceback()) end)
if not status then
    config.my_log(ngx.ERR, err)
    ngx.exit(ngx.OK)
end
