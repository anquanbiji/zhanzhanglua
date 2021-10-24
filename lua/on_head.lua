-- 加载自己的配置文件
local config = require "config"


local function main( ... )

    if not (ngx.ctx.is_close or ngx.ctx.is_skip) then 
        --ngx.log(ngx.ERR,'it is header')
        if  config.get_config_all_fun() then 
            -- 如果返回内容进行编码 则不返回content_length
            if config.get_config_encode_response() or config.get_config_is_error_info() then 
                ngx.header.content_length = nil 
            end 
        
            -- 暂时保存状态码   防止修改状态码后， 在log中看不到原始状态码
            ngx.ctx.status = ngx.status
            -- 如果请求异常 则 不返回状态码, 屏蔽返回异常内容
            if config.get_config_is_error_status() then 
                if ngx.status > 399 then 
                    -- 保存原始状态码
                     ngx.header.content_type = "text/html;charset=utf-8"
                    if ngx.var.new_status then 
                        ngx.var.new_status = ngx.status 
                    end 
                    ngx.status = ngx.HTTP_OK  
                end 
            end 
        end 
    end 
    -- 隐藏特定返回头
    ngx.header["X-Powered-By"] = 'http://doc.github5.com/zhanzhang/fanpa.html' ;
    ngx.header['Server'] = 'http://doc.github5.com/zhanzhang/fanpa.html';


end

-- 关闭了所有功能 直接退出 log一下
local status, err = xpcall(main, function() config.my_log(ngx.ERR, debug.traceback()) end)
if not status then
    config.my_log(ngx.ERR, err)
    ngx.exit(ngx.OK)
end




