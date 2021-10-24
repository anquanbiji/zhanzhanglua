--[[
rewrite阶段安全检测
1.浏览器识别检测
2.人机识别检测
3.扫描攻击检测
4.cc攻击检测
]]--
-- https://github.com/ktalebian/lua-resty-cookie
local ck = require "resty.cookie" -- cookie 库 
-- toruneko/lua-resty-crypto 
local cjson = require "cjson"

-- xiangnanscu/lua-resty-random
local random = require "resty.random"

-- 加载自己的配置文件
local config = require "config"
-- 攻击记录
--local status = require "status"

local function get_request( ... )
    -- body
    local request = {}
    request.ip = config.get_client_ip()  -- 客户端ip
    request.ua =  ngx.var.http_user_agent or ''
    --reqeust.fp = ngx.ctx.cookie_fp or '' 
    request.uri = ngx.var.request_uri
    request.host = ngx.var.host
    return request
end

local function send_check_code(second_c_k,value)
    local args = ngx.var.args or ''
    if #args == 0 then 
         args = "nocache="
    else 
         args = args .. "&nocache="
    end 
    ngx.header.content_type = "text/html;charset=utf-8"
    ngx.header.cache_control = "no-store"
	ngx.ctx.is_skip = true 
    ngx.say( [[ 
        <!DOCTYPE html>
        <html>
        <head>
        <title>智能防护检测</title>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, user-scalable=no, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0">  
        <link rel="stylesheet" href="//cdn.staticfile.org/mint-ui/2.2.8/style.css">
        </head>
        <body>
        <div id="app"  class="testClass">
        <mt-navbar v-model="selected">
        <mt-tab-item id="人机识别">智能防护</mt-tab-item> 
        </mt-navbar>
        <!-- tab-container -->
        <mt-tab-container v-model="selected">
        <mt-tab-container-item id="人机识别"> 
                <mt-field label="开门密码" placeholder="" v-model.trim="duanlian_yanzheng"  ></mt-field>
                <mt-field label="输入密码" placeholder="上面的数字" v-model.trim="duanlian_ma"  ></mt-field>     
                <mt-button @click.native="duanlian_handleClick" size="large" type="primary">继续访问</mt-button>            
        </mt-tab-container-item>    
        </mt-tab-container>
        </div>
        </body>
        <script src="//cdn.staticfile.org/vue/2.6.2/vue.js"></script>
        <script src="//cdn.staticfile.org/vue/2.6.2/vue.min.js"></script>
        <script src="//cdn.staticfile.org/vue-resource/1.5.1/vue-resource.min.js"></script>
        <script src="//cdn.staticfile.org/mint-ui/2.2.8/index.js"></script>
        <script>
        new Vue({
            el: '#app',
            data: {   
                selected: '人机识别',
                diaomao_money:'0',
                diaomao_qq:'',
                score:'',
                seen:false,
                duanlian_yanzheng:'0',
                duanlian_ma:'', 
            },
            methods: {
                setCookie: function(cname,cvalue,exdays)
                {
                        var d = new Date();
                        d.setTime(d.getTime()+(exdays*60*1000)); //60s
                        var expires = "expires="+d.toGMTString();
                        document.cookie = cname + "=" + cvalue + "; " + expires;
                },
                duanlian_handleClick: function() {      
                    if(this.duanlian_yanzheng == this.duanlian_ma){
                        this.setCookie("]] .. second_c_k ..[[","]] .. value ..[[" ,1);
                        window.location.replace("]] .. ngx.var.uri .."?" .. args .. [[" + (new Date()).getTime());        
                    }else{
                        this.$toast('密码错误 拒绝开门 请重试');
                    }
                },
                jifen_back: function(){ //返回到首页
                window.location.href="/";
                }
            },created(){
                    this.duanlian_yanzheng = Math.ceil(Math.random()*100);  
                }
        })	
        </script>
        </html>]])
    
    ngx.exit(ngx.HTTP_OK)
end 
local function send_fp_code(second_c_k )
    -- 非浏览器识别 https://github.com/fingerprintjs/botd
    local args = ngx.var.args or ''

    local token = config.get_random_token(32)
    ngx.header.content_type = "text/html;charset=utf-8"
    ngx.header.cache_control = "no-store"
    ngx.ctx.is_skip = true  -- 不需要body 过滤
    local html = [[ <!doctype html>
    <html>
        <head>
            <meta charset="utf-8">
            <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
            <meta http-equiv="Pragma" content="no-cache">
            <meta http-equiv="Expires" content="0">
            <script type="text/javascript">
                function setCookie(cname,cvalue,exdays)
                {
                    var d = new Date();
                    d.setTime(d.getTime()+(exdays*60*1000)); //60s
                    var expires = "expires="+d.toGMTString();
                    document.cookie = cname + "=" + cvalue + "; " + expires;      
                }          
                function jump(){
                    setCookie(']] .. second_c_k  .. [[',']] .. token .. [[',1);
                    window.location = ']] ..ngx.var.request_uri .. [[';
                }
            </script>
        </head>
        <body onLoad="javascript:jump()">
        </body>
    </html>]]

    ngx.say(html)
            
    ngx.exit(ngx.HTTP_OK   ) -- ngx.HTTP_OK


end

local function check_robot(session,data)
    if data.ck_status ~= 3 then 
        data.ck_status = 3 -- 当前检测机器人
        data.ck_check_bot_start_time = ngx.time() -- 检测机器人的开始时间
    end 
    data.ck_check_bot_type = 1  -- 检测机器人方法 1 数字计算
    --data.ck_check_bot_value = random.number(1,1000) -- 随机数
    data.ck_check_robot_value = random.number(1,1000)  -- 检测值
    -- 保存数据到session
    session:set(ngx.ctx.sesionid, cjson.encode(data), 20 * 60 * 1000 )

    -- 生成页面下发
    send_check_code(data.ck_key_fp,data.ck_check_robot_value)

end 
-- 初始化session
local function init_session(cookie,session,pre_session_key,first_c_k,fp_expire_starttime,fp_expire_endtime)
    -- 初始化session 
    local data = {}
    data.ck_password = config.get_random_token(16) -- 随机的hashmac
    data.ck_key_fp = config.get_random_token(32)  -- 生成fp cookie的key
    
    data.ck_start_time = ngx.time() -- 开始时间 
    data.ck_expires_starttime = fp_expire_starttime --- 10分钟过期
    data.ck_expires_endtime = fp_expire_endtime --- 10分钟过期
    data.ck_status = 0 -- 0 等待第一次下发 1 已经生成  2 重新下发(验证两次fp是否相同)

    data.request = get_request() -- 记录请求信息，当为攻击请求时 使用
    config.my_log(ngx.ERR,'init session')
    local session_id = config.get_random_token(32)  -- 32位随机值
    
    local success,err,forcible = session:set(pre_session_key ..session_id, cjson.encode(data), 20 * 60 * 1000 )
    if not success then 
        config.my_log(ngx.ERR,"share data save is wrong " ..err)
    end 
    -- expires = ngx.cookie_time(ngx.time() + 60 * 60 * 24 * 1) -- 1天有效期 
    cookie:set({
        key = first_c_k,
        value = session_id,
        path = '/',
        httponly = true
        
    })
    send_fp_code(data.ck_key_fp)

end 
-- pre_session_key  共享内存 sesionid 前缀
-- first_c_k 第一个cookie的key 每套服务随机一个
-- fp_expire_starttime fp 二次验证 起始时间
-- fp_expire_endtime fp 二次验证 结束时间
-- session_expire_time session连续在线多长时间 进行人机识别  单位min
local function start_check( pre_session_key,first_c_k,fp_expire_starttime,fp_expire_endtime,session_expire_time)

    ngx.ctx.is_skip = false -- 跳过header 和 body检测 当下发js 或者人机识别时
    ngx.ctx.is_close = false -- 跳过所有检测
    --ngx.ctx.is_white_ip = false -- 白名单请求
    ngx.ctx.is_spider = false  -- 蜘蛛请求
    
    config.my_log(ngx.ERR, "[start_check]" )
 
    -- 初始配置请求 
    if ngx.var.uri == '/github5' then  
        -- 没有配置认证hash 
        if not ngx.ctx.auth_md5 or ngx.ctx.auth_md5 == '' then 
            -- 获得32位随机hash 
            ngx.ctx.auth_md5 = config.get_random_token(32)
            local url = config.remote_houtai_url .. '?account_hash=' .. ngx.ctx.auth_md5 
            -- 保存认证信息到文件 
            config.save_md5_config(ngx.ctx.auth_md5)
            return ngx.redirect(url)
        else
            
            local url = config.remote_houtai_url  
            return ngx.redirect(url)
        end 
    end  
    -- 全局开关 判断 
    if not config.get_config_all_fun() or config.is_static_request() then 
        ngx.ctx.is_close = true 
        -- 关闭了所有功能 直接退出 log一下
        ngx.exit(ngx.OK)
    end
 
    -- IP白名单判断
    if  config.is_white_urls() or config.is_white_ip() then 
        --ngx.ctx.is_white_ip = ture 
        --config.my_log(ngx.ERR,'it is white urls ' .. tostring(type(ngx.ctx.is_close)) .. '[val]'..)
        ngx.ctx.is_close = true
        config.my_log(ngx.ERR,'it is white urls ' .. tostring(type(ngx.ctx.is_close)) .. '[val]'..tostring(ngx.ctx.is_close) .. '  ' )
        ngx.exit(ngx.OK)
        config.my_log(ngx.ERR,'it is white urls [end] ')
    end 
   
    -- 跳过内部请求
    if not ngx.req.is_internal() then 

        -- 如果验证蜘蛛 并且是真实蜘蛛 则不进行检查
        if  config.is_real_spider() then 
            ngx.ctx.is_spider = true 
            ngx.exit(ngx.OK)
        end 

        -- 浏览器检测
        if  config.get_config_check_browser() then 
            -- 是否有cookie_key
            local cookie,err = ck:new()
            if not cookie then 
                config.my_log(ngx.ERR,' cookie is wroing')
                ngx.ext(ngx.OK)
            end 
            local session = ngx.shared.attack
            -- 读取cookie的sessionid
            local first_key_value, err = cookie:get(first_c_k)
            if not first_key_value then 
                init_session(cookie,session,pre_session_key,first_c_k,fp_expire_starttime,fp_expire_endtime)
            else 
                local session_id = first_key_value  -- 32位随机值
                local data, flags = session:get(pre_session_key ..first_key_value)
                if data then     

                    data = cjson.decode(data)
                    ngx.ctx.sesionid = pre_session_key ..first_key_value -- 每个用户的唯一session 标志 后续body中使用
                    if data.ck_fp  then  
                        -- 保存fp code 
                        ngx.ctx.cookie_fp = data.ck_fp 
                    end 
                    -- 获得cookie fp信息
                    local second_key_value, err
                    if data.ck_key_fp then 

                        second_key_value, err = cookie:get(data.ck_key_fp)
                    end            
                    if data.ck_status == 0  then -- 第一次读取cookie fp 和重新下发fp cookie                    
                        if second_key_value  == nil or not second_key_value then 
                            -- status.attacklog(get_request())
                            send_fp_code(data.ck_key_fp)
                        end 
                        if #second_key_value ~= 32 then -- 验证fp是否正确 
                            -- status.attacklog(get_request())
                            send_fp_code(data.ck_key_fp)
                        end                             
                        data.ck_fp = second_key_value -- 保存fp                 
                        data.ck_fp_start_time =  ngx.time()  -- 当前fp开始的时间
                        data.ck_status = 1 -- fp已经设置完成
                        session:set(ngx.ctx.sesionid, cjson.encode(data), 20 * 60 * 1000 )
                    
                    elseif data.ck_status == 2 then -- 第二次下发 判断
                        local second_key_value, err = cookie:get(data.ck_key_fp)
                        if second_key_value == nil or  #second_key_value ~= 32 then 
                            if ngx.time() -  data.ck_fp_sec_start_time > 60 then -- 1分钟 都没有上报 
                                -- status.attacklog(get_request())
                                send_fp_code(data.ck_key_fp)
                            end 
                        else
                            if second_key_value ~= data.ck_fp then  -- 第二次获得的fp 与存储的不同 可能存在攻击行为
                                -- 下发人机识别 下发页面
                                -- status.attacklog(get_request())
                                config.my_log(ngx.ERR,"two fp code is bad")
                                check_robot(session,data)
                            else 
                                local next_time = random.number(1, 10) -- 过期时间 每次增加 1 到10倍                         
                                config.my_log(ngx.DEBUG,"session [ck_status = 2]" .. tostring(next_time))
                                data.ck_expires_starttime = data.ck_expires_starttime * next_time
                                data.ck_expires_endtime = data.ck_expires_endtime * next_time 
                                data.ck_fp = second_key_value -- 保存fp
                                data.ck_fp_start_time =  ngx.time()  -- 当前fp开始的时间
                                data.ck_status = 1 -- fp已经设置完成
                                session:set(ngx.ctx.sesionid, cjson.encode(data), 20 * 60 * 1000 )
                            end 

                        end 
                    elseif data.ck_status == 3  then -- 检测机器人判断
                        if data.ck_check_bot_type == 1 then -- 数字类型检验
                            local second_key_value, err = cookie:get(data.ck_key_fp)     
							
                            if second_key_value then 
							
								if tonumber(second_key_value) ~= tonumber(data.ck_check_robot_value) then 
									if ngx.time() -  data.ck_check_bot_start_time > 60 then -- 1分钟 都没有上报 
										-- 继续check_robot
										-- status.attacklog(get_request())
										config.my_log(ngx.ERR,"check the bot ")
										check_robot(session,data)
									end 
								else
									
									data.ck_fp_start_time =  ngx.time()  -- 当前fp开始的时间
									data.ck_start_time = ngx.time() 
									data.ck_status = 1 -- 检测通过 重置
									session:set(ngx.ctx.sesionid, cjson.encode(data), 20 * 60 * 1000 )
								end
							else 
								
								check_robot(session,data)
							end 
                        end 

            
                    elseif data.ck_status == 1 then 
                        -- 判断连续在线时间 
                        if config.get_config_online_time() then 
                            if ngx.time() -  data.ck_start_time > session_expire_time * 60   then 
                                config.my_log(ngx.ERR,"it is too long for online ")
                                check_robot(session,data)
                            end 
                        end 
                        -- 发送fp cookie 
                        if second_key_value then 
                            -- fp cookie 有效期为 60s,如果大于60s 还有cookie fp 则认为是非法请求
                            if ngx.time() -  data.ck_fp_start_time > 60 *2 then 
                                config.my_log(ngx.ERR, "maybe brute force ")
                                -- 封禁 还是机器人检测?
                                -- status.attacklog(get_request())
                                check_robot(session,data)
                            end 
                        end 
                        -- 更新session 结束时间 20分钟
                        -- session:expire(ngx.ctx.sesionid , 20 * 60 * 1000 )
						session:set(ngx.ctx.sesionid, cjson.encode(data), 20 * 60 * 1000 )
                    
                    end 

                    
                else 
                    -- status.attacklog(get_request())
                    -- sessionid 过期 ,则重新下发js 获取fp
                    config.my_log(ngx.ERR,"no  data for cookie in share dict: " .. first_key_value )
                    init_session(cookie,session,pre_session_key,first_c_k,fp_expire_starttime,fp_expire_endtime)  -- 重新初始化
                end 
            end 


            

        end --  check_brower


        config.my_log(ngx.ERR,'it is check code request')
        -- 判断请求速度 
        if config.denycc() then 
            -- status.attacklog(get_request())
            config.my_log(ngx.ERR,'it is CC request')
            config.say_html()
        end 
    end 
    

   


end


local function main( ... )
    -- 加载所有规则
    config.load_all_config(ngx.var.host) 
    local check_again = config.fp_expire_starttime()
    start_check('key',config.get_session_key(),check_again,check_again * 2 ,config.session_expire_time())   

end



local status, err = xpcall(main, function() ngx.log(ngx.ERR, debug.traceback()) end)
if not status then
    ngx.log(ngx.ERR, err)
    ngx.exit(ngx.OK)
end


