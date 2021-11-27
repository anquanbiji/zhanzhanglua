--[[

body阶段进行过滤
1.状态码 > 400 屏蔽错误输出
2.二次校验 客户端浏览器
3.返回html进行编码

]]--
local cjson = require "cjson"
-- 加载自己的配置文件
local config = require "config"

local function send_fp_code(second_c_k,fp )
    -- 非浏览器识别 https://github.com/fingerprintjs/botd
    local args = ngx.var.args or ''

    if #args == 0 then 
        args = "nocache="
    else 
         args = args .. "&nocache="
     end 
    local token = fp -- 第二次值 必须和第一次值相同
  
    local html = [[ <!doctype html>
    <html>
        <head>
            <meta charset="utf-8">
            
            <script type="text/javascript">
                function setCookie(cname,cvalue,exdays)
                {
                    var d = new Date();
                    d.setTime(d.getTime()+(exdays*60*1000)); //60s
                    var expires = "expires="+d.toGMTString();
                    document.cookie = cname + "=" + cvalue + "; " + expires;      
                }          
                function jump(){
					if (/HeadlessChrome/.test(navigator.userAgent) || navigator.webdriver) {
					  window.location = 'http://doc.github5.com/zhanzhang/fanpa.html';
					}
                    setCookie(']] .. second_c_k  .. [[',']] .. token .. [[',1);
                    window.location = ']] .. ngx.var.uri .."?" .. args .. [[' + (new Date()).getTime(); 
                }
            </script>
        </head>
        <body onLoad="javascript:jump()">
        </body>
    </html>]]

   return html 


end


local function main()

  -- 内容替换规则 
  if ngx.ctx.change_kg then  

	local is_change = true 
	if ngx.ctx.change_status_200 then 

		if ngx.ctx.status ~= ngx.HTTP_OK then  

			is_change = false
		end 
	end 
	if ngx.ctx.change_content_type_html then 

		local from, to, err = ngx.re.find(ngx.header["Content-Type"], "text/html","jo") 
		if not from then  

			is_change = false
		end 
	end 

	
	if is_change and ngx.ctx.change_old_code and ngx.ctx.change_new_code then 

		 ngx.arg[1] = ngx.re.gsub(ngx.arg[1],ngx.ctx.change_old_code, ngx.ctx.change_new_code,"i")
		 
	end 
	
	if is_change and ngx.ctx.change_tihuan_old_code and ngx.ctx.change_tihuan_new_code then 

		 ngx.arg[1] = ngx.re.gsub(ngx.arg[1],ngx.ctx.change_tihuan_old_code, ngx.ctx.change_tihuan_new_code,"i")
		 
	end  
  end 

  -- 关闭了所有功能 或者 跳过检测时 ，不执行反爬检查 
  if ngx.ctx.is_close or ngx.ctx.is_skip then 
	return 
  end 
  if  config.get_config_all_fun() then 
    -- 状态码 是否重写
    if ngx.ctx.status then
        -- 请求异常 屏蔽错误信息
      if ngx.ctx.status > 399 and config.get_config_is_error_info() then 
       
          config.my_log(ngx.ERR,"it is status > 400 request")
          ngx.arg[1] = config.get_error_page()
          ngx.arg[2] = true
          return  
     
      end 
    end 
    
    if config.get_config_check_browser_again() or config.get_config_encode_response() then 
  
      if  ngx.status == ngx.HTTP_OK then 
       
            if string.find(ngx.header["Content-Type"], "text/html")  then
           
              local chunk, eof = ngx.arg[1], ngx.arg[2]  -- 获取当前的流 和是否时结束
              local info = ngx.ctx.buf
              chunk = chunk or ""
              if info then
                ngx.ctx.buf = info .. chunk -- 这个可以将原本的内容记录下来
              else
                  ngx.ctx.buf = chunk
                  if  config.get_config_check_browser_again()  then 
					
                    if string.find(string.lower(chunk),"<html") and ngx.ctx.sesionid  and (ngx.req.get_method() == 'GET') then -- 请求方式是GET 才能跳转 否则还是会影响用户请求  
					
                      local session = ngx.shared.attack
					  if session then 
							
							local data, flags = session:get(ngx.ctx.sesionid)
						  if data then 
							
							
							data = cjson.decode(data)
							if data.ck_status and data.ck_status == 1 then 
							  if data.ck_fp_start_time and data.ck_expires_starttime then 
								if ngx.time() -  data.ck_fp_start_time > data.ck_expires_starttime then
								 
								  data.ck_password = config.get_random_token(16)  -- 随机的hashmac
								  data.ck_key_fp = config.get_random_token(32)  -- 生成fp cookie的key
								  data.ck_status = 2 -- fp已经设置完成 
								  data.ck_fp_sec_start_time = ngx.time()  -- 第二次开始验证的开始时间
								 
								  session:set(ngx.ctx.sesionid, cjson.encode(data), 20 * 60 * 1000 )  
								  ngx.arg[1] = send_fp_code(data.ck_key_fp, data.ck_fp) 
								  ngx.arg[2] = true 
								  return 
								end         
							  end     
							end 
						  end
                      end 						  
                    end 
                  end -- get_config_encode_response
              end

              
              if eof then

                if  config.get_config_encode_response()  then 
                  -- 开启编码 则进行进一步判断 
         
                  local returndata = string.lower(ngx.ctx.buf)
                  local isEncode = true 
                  if string.find(returndata,"<html") and string.find(returndata,"</html>") then
                    -- 检查真实蜘蛛程序
                    if config.get_config_check_spider() then 
                        --isEncode = config.is_real_spider() == true ? false : true 
                        isEncode = not ngx.ctx.is_spider
                    end 
                    if isEncode then 
                      ngx.arg[1] = [[<html><script src="https://cdn.staticfile.org/crypto-js/3.1.2/components/core.js"></script><script src="https://cdn.staticfile.org/crypto-js/3.1.2/components/enc-base64.js" ></script><script>document.write( CryptoJS.enc.Base64.parse("]] ..ngx.encode_base64(ngx.ctx.buf).. [[").toString(CryptoJS.enc.Utf8));</script></html>]]
                      ngx.ctx.buf = nil
                    end 
                  
                  else
                    ngx.arg[1] = ngx.ctx.buf
                  end 
                else
                    ngx.arg[1] = ngx.ctx.buf
                end 
              else      
                  ngx.arg[1] = nil -- 这里是为了将原本的输出不显示
              end
            end
          
      end 
    end
  end 
end


local status, err = xpcall(main, function() ngx.log(ngx.ERR, debug.traceback()) end)
if not status then
  ngx.log(ngx.ERR, err)
  ngx.exit(ngx.OK)
end
