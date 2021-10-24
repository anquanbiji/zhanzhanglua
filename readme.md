# 站长助手-反爬 

## 声明 
本项目可有效防护基础爬虫, 并不能防护所有爬虫, 请知晓!!!   
适用于个人及中小型网站, 如大型商业网站需要提供技术支持,请联系我们   


## 介绍 
对web网站进行保护，有效防止程序爬取,基础网站攻击,防止链接在QQ、微信等被标红 

## 功能

- 浏览器验证  
智能验证请求客户端是否为浏览器  
- 返回内容编码  
在不影响用户使用的情况下，对网站返回的html进行编码输出 
- 屏蔽错误信息  
禁止返回错误状态码和错误页面信息，可自定义错误页面
- 无头浏览器识别  
智能检测无头浏览器爬虫       
- 人机识别  
当检测到异常 需要用户手动输入验证码 进行进行操作  
- 加白功能  
针对URL/客户端IP/搜索引擎 进行加白   
目前支持搜索引擎 baidu,google,sogou,bing 等主流搜索引擎 

- 友好后台管理功能  
web后台管理,方便查看和修改配置  


## 部署  

首先安装站长助手  
```
cd /opt/
git clone https://github.com/anquanbiji/zhanzhanglua.git 

chmod 777 /opt/zhanzhanglua/rule.txt  
``` 



### 宝塔环境 

[宝塔](https://www.bt.cn/download/linux.html)安装   
```
yum install -y wget && wget -O install.sh http://download.bt.cn/install/install_6.0.sh && sh install.sh
```

找到nginx.conf文件  在http{ 下 添加 

```
include /opt/zhanzhanglua/nginx_conf/in_http_block.conf;
```

重启nginx 
```
nginx -t 
nginx -s reload  
```
### openresty 

[openresty](https://openresty.org/cn/linux-packages.html)安装  
```
wget https://openresty.org/package/centos/openresty.repo
sudo mv openresty.repo /etc/yum.repos.d/
sudo yum check-update
sudo yum install -y openresty
```



执行如下命令,查看配置文件 
```
openresty -t 
```
返回结果 
```
nginx: the configuration file /usr/local/openresty/nginx/conf/nginx.conf syntax is ok
nginx: configuration file /usr/local/openresty/nginx/conf/nginx.conf test is successful
```

在 /usr/local/openresty/nginx/conf/nginx.conf  的 http{ 下 添加  
```
include /opt/zhanzhanglua/nginx_conf/in_http_block.conf;
```


### 其他环境 
站长助手依赖nginx lua模块，所有您使用的是apache,iis等其他web服务器,建议先安装openresty或宝塔环境,使用反代方式请求您的网站 


## 后台使用教程

- 访问/github5 路径   
网站域名后加上/github5 路径，将会打开操作后台 (第一次访问 请进行注册，直接输入手机号和密码)   

- 配置说明  

## 手动配置说明
如果对nginx足够了解，可以手动进行配置, 以下所有指令支持server 或 location 块

常见功能  

- 关闭所有功能 

```
set $config_all_fun false; 
```

- 关闭浏览器检测  
```
set $config_check_browser false; 
```

- 关闭浏览器多次检测 

```
set $config_check_browser_again false; 
```
 
- 关闭返回编码功能  
```
set $config_encode_response false;
```

- 关闭屏蔽状态码 
```
set $config_is_error_status false;
```

- 关闭屏蔽错误信息  
```
set $config_is_error_info false;
```

## 常见问题 

- 无法保存规则到本地文件  
修改规则文件的权限  
```
chmod 777 /opt/zhanzhanglua/rule.txt  
```

## 技术支持

有任何问题 请[联系我们](https://support.qq.com/products/352799)

## TODO 
- 前端js代码混淆  
- 支持多种编码方式  
- 无头浏览器深入检测  

## 致谢 

[lua-nginx-module](https://github.com/openresty/lua-nginx-module)    
[vue-manage-system](https://github.com/lin-xin/vue-manage-system)   
[github5](http://github5.com)  