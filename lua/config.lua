--[[ 
加载配置信息

]]--

local resolver = require "resty.dns.resolver"
local http = require "resty.http"
-- xiangnanscu/lua-resty-random
local random = require "resty.random"
local cjson = require "cjson"

local _M = {}
_M.config_all_fun = 'config_all_fun' -- 全局开关
_M.config_check_browser = 'config_check_browser' -- 检测浏览器
_M.config_check_browser_again = 'config_check_browser_again' -- 再次检测浏览器
_M.config_encode_response = 'config_encode_response' -- 编码返回内容
_M.config_check_spider = 'config_check_spider' -- 检测搜索引擎蜘蛛
_M.config_bad_scan = 'config_bad_scan' -- 检测扫描请求
_M.config_online_time = 'config_online_time' -- 用户持续在线时间
_M.config_error_page = 'config_error_page' -- 屏蔽错误页面
_M.config_is_error_info = 'config_is_error_info' -- 屏蔽错误页面信息
_M.config_error_status = 'config_error_status' -- 屏蔽错误状态码
_M.config_white_ips = 'config_white_ips'  -- 白名单ip
_M.config_is_error_status = 'config_is_error_status' -- 屏蔽错误状态码

_M.config_white_urls = 'config_white_urls'  -- 白名单urls
_M.config_fp_expire_starttime = 'config_fp_expire_starttime' -- 重新检测fp
_M.config_session_expire_time = 'config_session_expire_time' -- session持续在线最大时间
_M.config_session_key = 'config_session_key' -- session 在cookie中的key

_M.default_host = 'default' -- 默认域名
_M.proxy = 'proxy_' -- 上游proxy代理前缀
_M.rulefile = '/opt/zhanzhanglua/rule.txt'  -- 规则文件

-- 更新404 页面信息
_M.remote_houtai_url = 'http://zhanzhang.houtai.github5.com:8081/#login'

--站群系统 加载host配置的地址 url?domain=host
_M.remote_api_url = 'http://zhanzhang.houtai.github5.com:8081/github5/zhanzhang/fanpa/rule.json'


_M.global_error_page = 'error'



--[[
参数: 空
功能: 生成一个随机的32位值
]]--
local function get_random_key( number )
    local key = random.token(number) -- 32位 a-z A-Z 0~9
    return key 
end
local function is_config_for_variable(var )

   
      -- 开启所有功能 变量设置 
    if ngx.var[var] == nil or ngx.var[var] == '' then 
        --兼容 当在一个server 使用set指令配置变量$a ，在另一个server 读取到的变量$a 为空值 
        -- 从临时变量获得值
        local r = ngx.ctx[var]     

        if r ~= nil then 
            
          
            
            if r == 'false' or not r then 
                
                return false 
            else
                
                return true 
            end  
        end 
    elseif ngx.var[var] == 'false' or not ngx.var[var] then 
        return false
    end 
    return false 

end 

function _M.my_log( level,info )
    -- body
    -- ngx.log(level,info)
end
--[[
保存配置到文件
]]--

function _M.save_waf_config( ... )
    -- body

    local file = io.open(_M.rulefile,"w+")
	if file then 
		-- ngx.log(ngx.ERR,'write config')
		local session = ngx.shared.wafconfig 
		for index, k in pairs(session:get_keys(10240)) do 
			local data = session:get(k)
			file:write(data .. '\n')
		end 
		file:close()
	end 
end
--[[
保存认证的hash 
]]--
function _M.save_md5_config( md5 )
    local session = ngx.shared.wafconfig
    local default_rules = session:get(_M.default_host) 
    if default_rules then
        default_rules = cjson.decode(default_rules) 
    else 
        return 
    end 
    default_rules.auth.md5 = md5
    session:set(_M.default_host, cjson.encode(default_rules),0)
    
    _M.save_waf_config()
end
--[[

参数:空
功能:从共享内存加载配置


]]--
function _M.load_all_config(host)

    local session = ngx.shared.wafconfig
    local rules = session:get(host) -- 先根据请求域名进行获取 配置，如果域名下 配置都为空
    local default_rules = session:get(_M.default_host) 
    if rules == nil then    
        rules = default_rules

    end 
    if default_rules then
        default_rules = cjson.decode(default_rules) 
        -- 加载搜索引擎名称 
        ngx.ctx.search_engines =  default_rules.rule.config_whitle_search_engines 
        -- CC攻击配置 
        ngx.ctx.config_CCrate  = default_rules.rule.config_CCrate 
        -- 获得规则认证 hash 
        ngx.ctx.auth_md5 = default_rules.auth.md5
        -- 规则的hash值 
        ngx.ctx.rule_hash = default_rules.rule.config_rule_hash
        
        -- 默认错误页面
        ngx.ctx.config_error_page = default_rules.rule.config_error_page  
    end 

    if rules then 

        rules = cjson.decode(rules)

        ngx.ctx.config_fp_expire_starttime = 5 * 60 

     
        ngx.ctx.config_session_expire_time = 300 -- 默认为5个小时 在线时长


        ngx.ctx.config_session_key = 'SESSION_KEY_PRE'
        -- 防护规则配置
        if rules.rule then 
            for key, value in pairs(rules.rule) do 
                --ngx.log(ngx.ERR,'load config [key]'..key ..'[value]'..value)
                ngx.ctx[key] = value 
            end 
            -- 没有配置的host 则不进行设置
            if not rules.rule.config_session_key and host == rules.host  then 
                ngx.ctx.config_session_key = get_random_key(32)
                rules.rule.config_session_key = ngx.ctx.config_session_key
                session:set(host,cjson.encode(rules),0) 
                
            end 
        end 
        ngx.ctx[_M.config_white_ips] = ''
        -- IP 白名单配置
        if rules.rule[_M.config_white_ips] then 
            ngx.ctx[_M.config_white_ips] = rules.rule[_M.config_white_ips]
        end 

        -- 白名单url列表
        ngx.ctx[_M.config_white_urls] = ''

        ngx.ctx[_M.config_white_urls] = rules.rule[_M.config_white_urls]
        

    end 
end 
--[[

是否为静态请求
]]--
function _M.is_static_request( ... )

    if ngx.re.find(ngx.var.uri,'.ico|.png|.jpg|.js') then 
            ngx.log(ngx.ERR,'[static uri]'.. ngx.var.uri .. 'it is true')
            return true
    end
    return false;
end
--[[ 
参数: 空
功能:全局开关 
说明: 返回 false 时，关闭所有阶段的防护检测

使用示例:关闭所有功能
set $config_all_fun false;
]] 

function _M.get_config_all_fun()
    return is_config_for_variable(_M.config_all_fun)
end 

--[[
参数: 空
功能: 检测浏览器
说明: 返回 false 不在rewrite阶段 检查浏览器

set $config_check_browser false;
]]

function _M.get_config_check_browser() 
    -- 开启所有功能 变量设置
    return is_config_for_variable(_M.config_check_browser )
end 


--[[
参数: 空
功能: 检测浏览器
说明: 返回 false 不在body阶段 再次检查浏览器

set $config_check_browser_again false;
]]

function _M.get_config_check_browser_again() 
    if _M.get_config_check_browser() then 
    -- 开启所有功能 变量设置
        return is_config_for_variable(_M.config_check_browser_again)
    end 
    return false
end 
--[[
参数: 空
功能: 编码返回内容
说明: 返回 false 不在body_filter编码返回内容

set $config_encode_response false;
]]
function _M.get_config_encode_response() 
    
    return is_config_for_variable(_M.config_encode_response)

end 



--[[
参数: 空
功能: 验证蜘蛛程序
说明: 返回 true 蜘蛛程序 不进行编码返回

set $config_check_spider true;
]]
function _M.get_config_check_spider() 

    return is_config_for_variable(_M.config_check_spider)

end 

--[[
参数: 空
功能: 检测扫描请求
说明: 返回 true rewrite阶段检测机器人扫描

set $config_bad_scan true;
]]
function _M.get_config_bad_scan() 

    return is_config_for_variable(_M.config_bad_scan)

end 


--[[
参数: 空
功能: 检测连续在线时间
说明: 返回 true rewrite阶段检测连续在线时间

set $config_online_time true;
]]
function _M.get_config_online_time() 

    return is_config_for_variable(_M.config_online_time)

end 
--[[
参数: 空
功能: 检测扫描请求
说明: 判断请求header和ua 判断是否为非法软件请求

]]

function _M.is_scanner_request( ... )

    if  ngx.var.http_Acunetix_Aspect then
        return true
    elseif ngx.var.http_X_Scan_Memo then 
        return true 
    end 
    local rule = '(HTTrack|harvest|audit|dirbuster|pangolin|nmap|sqln|-scan|hydra|Parser|libwww|BBBike|sqlmap|w3af|owasp|Nikto|fimap|havij|PycURL|zmeu|BabyKrokodil|netsparker|httperf|bench| SF/)'
    local ua = ngx.var.http_user_agent
    if ua ~= nil then 
        if ngx.re.match(ua,rule,"isjo") then 
            return true
        end 
    end 

    return false
end
--[[
参数: 空
功能: 开/关 显示错误页面
说明: 返回 true 屏蔽错误页面

set $config_is_error_info true;
]]
function _M.get_config_is_error_info() 

    return   is_config_for_variable(_M.config_is_error_info)

end 



--[[
参数: 空
功能: 开/关 显示400以上状态码
说明: 返回 true 屏蔽状态码

set $config_is_error_status true;
]]
function _M.get_config_is_error_status() 

    return is_config_for_variable(_M.config_is_error_status)

end 

--[[

获得客户端ip地址
]]--

function _M.get_client_ip( ... )
    -- body
    if ngx.resp.get_headers()['x-real-ip'] then 
        return ngx.resp.get_headers()['x-real-ip']
    end  
    return ngx.var.remote_addr 
end
--[[
参数: 空
功能: 是否是真实蜘蛛
说明: 返回 false 蜘蛛程序 不进行编码返回
参考: 
https://github.com/woothee/lua-resty-woothee/blob/HEAD/README.md
]]
function _M.is_real_spider() 

    local ua = ngx.var.http_user_agent
    local search_engine = {};
    search_engine['yandex'] = [[spider(.*)yandex\.(ru|net|com)]] -- 178-154-171-85.spider.yandex.com
    search_engine['yahoo']  = [[crawl(.*)yahoo\.(net|com|jp)]]  -- g1093.crawl.yahoo.net
    search_engine['bing']   = [[msnbot(.*)search\.msn\.com]] -- msnbot-131-253-24-10.search.msn.com
    search_engine['Google'] = [[crawl(.*)googlebot\.com]] -- crawl-66-249-73-24.googlebot.com
    search_engine['Baidu']  = [[baiduspider(.*)crawl\.baidu\.(com|jp)]] -- baiduspider-110-181-108-81.crawl.baidu.com
    search_engine['sogou']  = [[sogouspider(.*)crawl\.sogou\.com]]  -- sogouspider-110-211-125-104.crawl.sogou.com
    search_engine['ahrefs'] =  [[ip(.*)a\.ahrefs\.com]] 
    search_engine['semrush'] = [[crawl3\.bl\.semrush\.com]]
    search_engine['petalsearch'] = [[petalbot(.*)petalsearch\.com]] 
    search_engine['mj12bot'] = [[static\(.*)\.clients\.your-server\.de]]
    
    

    if ua then 
        local m, err = ngx.re.match(ua, ngx.ctx.search_engines)
        if m then
            local name = m[0] 
            if #name > 0 then 
               
                local addr_ip = _M.get_client_ip()

                local session = ngx.shared.tmpdb
                if session:get('bot_' .. addr_ip) then 
                    return true 
                end 


                local domain = search_engine[name]
                if not domain then
                    return false
                end

                local r, err = resolver:new{
                    nameservers = {"114.114.114.114", {"8.8.8.8", 53}} ,
                    retrans = 1,  -- 1 retransmissions on receive timeout
                    timeout = 2000,  -- 2 sec
                    no_random = true, -- always start with first nameserver
                }
                if not r then    
                    return false
                end

            
                local answers, err = r:reverse_query(addr_ip)
                if not answers then
                    return false
                end

            
                for i, ans in ipairs(answers) do
                    if ans.ptrdname then
 
                        local ret = ngx.re.find(ans.ptrdname, domain)
                        if ret then
                            ngx.log(ngx.ERR,"[my_ptr]" .. ans.ptrdname)
                            session:set('bot_' .. addr_ip, 1, 36000) -- 缓存10小时
                            return true
                        end
                    end
                end
            end 
        end 
        
    end 
    
    
    return false 
end 
--[[

参数:空
功能:返回html错误信息

]]--
function _M.say_html()
    ngx.header.content_type = "text/html;charset=utf-8"
    --ngx.status = ngx.HTTP_FORBIDDEN
    ngx.say(_M.get_error_page())
    ngx.exit(ngx.HTTP_OK)
    
end


--[[

set $CCrate 120/60

如果有fp 使用fp统计 否则使用ip统计
]]--

function _M.denycc( ... )

    local CCrate =  ngx.ctx.config_CCrate 
    if CCrate ~= nil   then 
        local uri=ngx.var.uri
        local CCcount=tonumber(string.match(CCrate,'(.*)/'))
        local CCseconds=tonumber(string.match(CCrate,'/(.*)'))
        if CCcount == 0 or CCseconds == 0 then 
            return false
        end 
        local token 
        if  ngx.ctx.cookie_fp ~= nil then 
             token =ngx.ctx.cookie_fp..uri
        else 
            token = _M.get_client_ip() .. uri 
        end 
        local limit = ngx.shared.tmpdb
        if limit then 
            local req,_=limit:get(token)
            if req then
                if req > CCcount then
                    return true
                else
                    limit:incr(token,1)
                end
            else
                limit:set(token,1,CCseconds)
            end
        end 
    end 

    return false
end

--[[
参数: 空
功能: 返回异常时显示页面
说明: 当返回状态码>399 时，返回的内容信息
]]
function _M.get_error_page() 
    -- 蜘蛛程序
    if ngx.ctx.is_spider then 
        -- 允许所有
        if ngx.var.uri == '/robots.txt' then 
            return [[
                User-agent: *
                Allow:/
                ]]
        elseif ngx.var.uri == '/sitemap.xml' then 

        end 
    
    end 
    return _M.global_error_page .. _M.get_random_token(32)

end 




--[[
参数: 空
功能: 生成一个随机的32位值
]]--

function _M.get_random_token( num )
    return get_random_key(num)
 end
--[[
参数: 空
功能: 生成随机cookie key,用于保存session信息

]]
function _M.get_session_key() 
    -- local session = ngx.shared.wafconfig
    -- if session then 
    --     local session_key, flags = session:get("config_session_key")
    --     if session_key == nil then 
    --         session_key = get_random_key(32)
    --         session:set("config_session_key", session_key)
    --     end 
    --     return session_key
    -- end 
    -- return 'SESSION_KEY_COOKIE'
    return ngx.ctx.config_session_key or 'SESSION_KEY_COOKIE'

end 

--[[
参数: 空
功能: 第二次浏览器验证的 开始时间 结束时间为乘以2

]]
function _M.fp_expire_starttime()  
    
    return ngx.ctx.config_fp_expire_starttime or  5 * 60 

end 

--[[
参数: 空
功能: session持续在线多少分钟 ，进行人机验证
set $session_expire_time  300; -- session持续在线5个小时 进行人机验证


]]
function _M.session_expire_time() 


    return ngx.ctx.config_session_expire_time or 300 
end 

function _M.send_http_post( url,data )
    local httpc = http.new()
    local res, err = httpc:request_uri(url, {
        method = "POST",
        body = cjson.encode(data),
        headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded",
        },
    })
    if not res then
        ngx.log(ngx.ERR, "request failed: ", err)
        return nil 
    end

    if res.status == 200 then 
        return res.body
    end 
    return nil 
end
-- 发送http请求
function _M.send_http_get(url)
    local httpc = http.new()
    local res, err = httpc:request_uri(
        url,{
            method = "GET",
            ssl_verify = false,
          }
    )
    if not res then
        ngx.log(ngx.ERR, "[send_http_get]request failed: ", err)
        return nil 
    end
    if 200 == res.status then
        return res.body
    end

   return nil  
end
--[[

判断请求是否是白名单ip
]]--

function _M.is_white_ip()
    -- body
    local ips = ngx.ctx[_M.config_white_ips]    
    if ips and #ips > 0 then 
        if ngx.re.find(_M.get_client_ip(),ips) then 
            return true 
        end
    end  
    return false
end

--[[
判断请求是否在白名单urls
]]--
function _M.is_white_urls()
    -- body
    local urls = ngx.ctx[_M.config_white_urls]    
    if urls and #urls > 0 then 
        
        if ngx.re.find(ngx.var.uri,urls) then 
            ngx.log(ngx.ERR,'[white urls]'..urls ..'[request url]'.. ngx.var.uri .. 'it is true')
            return true
        end
    end  
    ngx.log(ngx.ERR,'[white urls]'..urls ..'[request url]'.. ngx.var.uri .. 'it is false')
    return false
end


function _M.get_request( ... )
    -- body
    local request = {}
    request.ip = _M.get_client_ip()  -- 客户端ip
    request.ua =  ngx.var.http_user_agent or ''
    --reqeust.fp = ngx.ctx.cookie_fp or '' 
    request.uri = ngx.var.request_uri
    request.host = ngx.var.host
    return request
end
return _M