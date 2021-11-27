# github5站长助手  

## 介绍 
基于lua开发的开源站长助手, 实现常见的站长功能:   

- 智能防爬虫  
- 批量添加站长统 
- 批量替换网页内容
- 智能管理网站有效链接
- 批量生成robots.txt
- 批量屏蔽网站错误信息
- 自动推送到百度
- 更多功能开发中,欢迎联系我们反馈您的需求，[QQ群](http://u.720life.cn/s/f2316816)

## 功能界面

![由gif.github5.com进行录制](/gif/zhanzhang/seo.gif)
![由gif.github5.com进行录制](/gif/zhanzhang/fanpa.png)

## 功能详情 

### [反爬防护](http://doc.github5.com/zhanzhang/fanpa.html)  
对网站进行安全防护,防止网络爬虫恶意请求   


主要功能

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


### SEO优化

主要功能  

- 页面修改  
对每个html页面</html>前插入设置的代码,如插入站长统计，站长工具自动收录代码   
对网站返回内容进行替换/删除(新内容为空), 比如删除网站多余描述信息，或替换成站长联系方式等，根据特定需求进行使用即可   


- 链接管理 
根据配置，智能统计网站所有链接地址   
根据统计到的链接，生成站点地图   
将统计到的链接 推送到百度后台  

### 外链发布(开发中)
主要功能  

- 免费发布 
将域名提交到上千个外部网站上   

  

### 网站监控 (开发中)



## 部署  

首先安装站长助手  
```
cd /opt/
git clone https://github.com/anquanbiji/zhanzhanglua.git 
chmod 777 /opt/zhanzhanglua/log.txt 
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

登录后台  
如果您的网站域名是www.atghost.cn   
如果您的网站ip是: 47.1.2.4  

您的后台地址:  
www.atghost.cn/github5   
或者 
47.1.2.4/github5  

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
include  /opt/zhanzhanglua/nginx_conf/in_http_block.conf;
```  

重启openresty 
```
openresty  -t 
openresty  -s reload  
```

登录后台  
如果您的网站域名是www.atghost.cn   
如果您的网站ip是: 47.1.2.4  

您的后台地址:  
www.atghost.cn/github5   
或者 
47.1.2.4/github5 

### 其他环境 
站长助手依赖nginx lua模块，所有您使用的是apache,iis等其他web服务器,建议先安装openresty或宝塔环境,使用反代方式请求您的网站 


## 后台使用教程

- 访问/github5 路径   
网站域名后加上/github5 路径，将会打开操作后台 (第一次访问 请进行注册，直接输入手机号和密码)   

- 配置说明  
请查看界面上后右侧帮助信息   

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
每个问题10元[QQ群](http://u.720life.cn/s/f2316816)   

[需求反馈地址](https://support.qq.com/products/352799)
