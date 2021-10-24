
local config = require "config"

local function main( ... )
   config.save_waf_config()
end 

local status, err = xpcall(main, function() ngx.log(ngx.ERR, debug.traceback()) end)
if not status then
    ngx.log(ngx.ERR, err)
end
