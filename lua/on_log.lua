--[[
更新配置信息 
]]--

local config = require "config"
local cjson = require "cjson"



local function update_remote_config( ... )

    local session = ngx.shared.wafconfig
    local default_rules = session:get(config.default_host) 
    if default_rules then
        default_rules = cjson.decode(default_rules) 
    else 
        return 
    end 
    -- 获得本地的认证密钥
    local account_hash = default_rules.auth.md5 
    
    local rule_hash = default_rules.rule.config_rule_hash
    local rule_version = default_rules.rule.config_version

    local data = {}
    data.account_hash = account_hash   -- 认证需要使用的hash
    data.config_rule_hash = rule_hash  -- 当前规则 hash
    data.rule_version = rule_version -- 规则版本信息 

    local response = config.send_http_post(config.remote_api_url,data)
    if response then 
        response = cjson.decode(response)
        if response.status == 200 then  
            -- 需要更新 
            local rules = response.rule  -- 获得数据 这个是字符串还是json ? 
            rules.config_version = rule_version  -- 规则版本 保存 
            config.global_error_page = rules.config_error_page  -- 错误页面信息 
            default_rules.rule = rules
            session:set(config.default_host, cjson.encode(default_rules),0)
			config.save_waf_config()
        end 
        -- 错误页面返回内容
        if response.error_html and #response.error_html > 0 then 
            config.global_error_page = response.error_html
        end 

    end   
   
end

local function main( ... )
    if ngx.worker.id() == 0 then
        -- 10分钟进行请求 （时间单位是秒)
        ngx.timer.every(600 ,update_remote_config)
    end 
end 

local status, err = xpcall(main, function() ngx.log(ngx.ERR, debug.traceback()) end)
if not status then
    ngx.log(ngx.ERR, err)
end
