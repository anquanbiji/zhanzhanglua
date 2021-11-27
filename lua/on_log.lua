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
			if rules then 
				rules.config_version = rule_version  -- 规则版本 保存 
				config.global_error_page = rules.config_error_page  -- 错误页面信息 
				default_rules.rule = rules
			end 
			
			local changecontent = response.changecontent  -- 插入代码
			if changecontent then 
				default_rules.changecontent = changecontent 
			end 
			
			local tuisong = response.tuisong  -- 推送设置  
			if tuisong then 
				default_rules.tuisong = tuisong 
			end 
            session:set(config.default_host, cjson.encode(default_rules),0)
			config.save_waf_config()
        end 
        -- 错误页面返回内容
        if response.error_html and #response.error_html > 0 then 
            config.global_error_page = response.error_html
        end 

    end   
   
end

local function split(str,delimiter)
    local dLen = string.len(delimiter)
    local newDeli = ''
    for i=1,dLen,1 do
        newDeli = newDeli .. "["..string.sub(delimiter,i,i).."]"
    end

    local locaStart,locaEnd = string.find(str,newDeli)
    local arr = {}
    local n = 1
    while locaStart ~= nil
    do
        if locaStart>0 then
            arr[n] = string.sub(str,1,locaStart-1)
            n = n + 1
        end

        str = string.sub(str,locaEnd+1,string.len(str))
        locaStart,locaEnd = string.find(str,newDeli)
    end
    if str ~= nil then
        arr[n] = str
    end
    return arr
end 
--[[
每天执行一次功能 
百度推送
免费外链发布 
]]--
local function every_day_task( ... )
	-- 开启百度推送 
	if ngx.ctx.ts_baidu_tokens and #ngx.ctx.ts_baidu_tokens > 10 then  
		local t  = split(ngx.ctx.ts_baidu_tokens , '\n')
		--ngx.log(ngx.ERR, '[ts_baidu_tokens] ' .. ngx.ctx.ts_baidu_tokens)
		
		for k ,v in pairs(t) do 
			if #v > 4 then 
				--ngx.log(ngx.ERR, '[ts_baidu_tokens] [1] ' )
				if string.find(v, "|")  then
					local item = split(v, '|')
					local domain = item[1]
					local token = item[2]  
					local list = {}
					--ngx.log(ngx.ERR, '[ts_baidu_tokens] [2] ' )
					local file = io.open(config.logfile,"r")
					if file then	
					
						local post_data = ''
						for line in file:lines() do

							line = string.gsub(line,"\r","")
							line = string.gsub(line,"\n","")
							local data = cjson.decode(line)
							if data.h ~= nil and data.d ~= nil and #data.h == 32 and ngx.var.server_name == domain  then 
								if ngx.ctx.ts_new_urls then 
									--ngx.log(ngx.ERR, '[ts_baidu_tokens] [3] ' )
									if ngx.time() - data.t < 24 * 3600 then  
										--ngx.log(ngx.ERR, '[ts_baidu_tokens] [4] ' )
										post_data = post_data .. data.s .. '://' .. data.d .. data.u .. '\n'
										
									end 
									
								elseif ngx.ctx.ts_loop_urls then 
									--ngx.log(ngx.ERR, '[ts_baidu_tokens] [5] ' )
									if  math.fmod((ngx.time() - data.t) / 24 / 3600 , tonumber(ngx.ctx.ts_loop_day)) == 0 then
										--ngx.log(ngx.ERR, '[ts_baidu_tokens] [6] ' )
										post_data = post_data .. data.s .. '://' .. data.d .. data.u .. '\n'
									end 
								end 
								
							end                
						
						end	
						-- 发送post消息  
						local url = 'http://data.zz.baidu.com/urls?site=' .. domain .. '&token=' .. token  
						local res = config.send_http_post(url,post_data)
						if res then 
						-- 推送结果 
							
						end 

						file:close()
					end 
				end 
			end 
		
		end 
	
	end 
end 

local function main( ... )
    if ngx.worker.id() == 0 and ngx.timer.pending_count() + ngx.timer.running_count() == 0 then
        -- 10分钟进行请求 （时间单位是秒)
        ngx.timer.every(600 ,update_remote_config)
		-- 24个小时 执行一次 
		ngx.timer.every(3600 * 24 ,every_day_task)
		
    end


	-- 进行url统计  
	if ngx.ctx.ts_kg then  

		-- 不是内部请求进行统计 
		if not ngx.req.is_internal() then  
			-- 状态码 200 

			local is_record = true 
			if ngx.req.get_method() == 'GET' and ngx.ctx.status == ngx.HTTP_OK then  
				local from, to, err = ngx.re.find(ngx.header["Content-Type"], "text/html","jo") 
				if  from then  
				
					
					-- 判断条件  
					
					if #ngx.ctx.ts_domains > 0 then  
						local from, to, err = ngx.re.find(ngx.var.server_name, ngx.ctx.ts_domains,"jo") 
						if not from then 
			
							is_record = false 
						end 
					end  
					if  #ngx.ctx.ts_white_urls > 0 then  
						local from, to, err = ngx.re.find(ngx.var.uri, ngx.ctx.ts_white_urls,"jo") 
						if not from then 
		
							is_record = false 
						end 
					end 
					
					if  #ngx.ctx.ts_black_urls > 0 then  
						local from, to, err = ngx.re.find(ngx.var.uri, ngx.ctx.ts_black_urls,"jo") 
						if  from then 
					
							is_record = false 
						end 
					end 
					-- 记录日志
					if is_record then 
						-- 判断是否已经记录过 
						local url = ngx.var.server_name .. ngx.var.uri 
						local u_md5 = ngx.md5(url)
						local db= ngx.shared.urlhash
						if db and u_md5 then  
						
							local has_hash = db:get(u_md5) 
							if not has_hash then
								-- 新的hash 
								db:set(u_md5, '1',0) -- 存储hash 
								
								local data = {}
								data.u = ngx.var.request_uri    -- 请求URL 
								data.d = ngx.var.server_name  -- 请求域名
								data.s = ngx.var.scheme -- 请求的协议
								data.t = ngx.time()  -- 请求时间  
								data.h = u_md5  -- hash值 重启时进行初始化 
								config.save_log(data) -- 保存数据到文件 
								
								
							end 
						end 
					
					end -- if is_record 
					
				end  -- if form 
			end -- if GET
		end 
	
	end 
end 

local status, err = xpcall(main, function() ngx.log(ngx.ERR, debug.traceback()) end)
if not status then
    ngx.log(ngx.ERR, err)
end
