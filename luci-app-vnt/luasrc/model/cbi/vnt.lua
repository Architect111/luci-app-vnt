local http = luci.http
local nixio = require "nixio"

m = Map("vnt")
m.description = translate('vnt2 二合一异地组网工具，同时支持客户端/服务端模式<br>官网：<a href="http://rustvnt.com/">rustvnt.com</a>&nbsp;&nbsp;项目地址：<a href="https://github.com/vnt-dev/vnt">github.com/vnt-dev/vnt</a>&nbsp;&nbsp;安卓端、GUI：<a href="https://github.com/lmq8267/VntApp">VntApp</a>&nbsp;&nbsp;<a href="http://qm.qq.com/cgi-bin/qm/qr?_wv=1027&k=o3Rr9xUWwAAnV9TkU_Nyj3yHNLs9k5F5&authKey=l1FKvqk7%2F256SK%2FHrw0PUhs%2Bar%2BtKYx0pLb7aiwBN9%2BKBCY8sOzWWEqtl4pdXAT7&noverify=0&group_code=1034868233">QQ群</a>')

-- 状态面板
m:section(SimpleSection).template  = "vnt/vnt_status"

-- 全局唯一配置段 global，vnt2 合并后不再区分 cli / vnts
s = m:section(TypedSection, "global", translate("VNT2 全局设置"))
s.anonymous = true

s:tab("general", translate("基础设置"))
s:tab("server_list", translate("多服务端列表（负载均衡/容灾）"))
s:tab("privacy", translate("高级传输设置"))
s:tab("tun_mode", translate("虚拟网卡&端口映射"))
s:tab("security", translate("TLS证书加密"))
s:tab("infos", translate("运行信息面板"))
s:tab("upload", translate("程序上传更新"))

-- 总开关
switch = s:taboption("general",Flag, "enabled", translate("启用VNT2"))
switch.rmempty = false

btncq = s:taboption("general", Button, "btncq", translate("重启程序"))
btncq.inputtitle = translate("重启")
btncq.description = translate("修改参数后点击重载程序")
btncq.inputstyle = "apply"
btncq:depends("enabled", "1")
btncq.write = function()
  os.execute("/etc/init.d/vnt restart ")
end

token = s:taboption("general", Value, "token", translate("组网Token"),
	translate("同一局域网标识，相同Token设备互通，必填"))
token.optional = false
token.password = true
token.placeholder = "test_token"
token.maxlength = 63
token.minlength = 1

localadd = s:taboption("general",DynamicList, "localadd", translate("本地LAN网段"),
	translate("本机内网网段，例：192.168.1.0/24"))
localadd.placeholder = "192.168.1.0/24"

forward = s:taboption("general",Flag, "forward", translate("开启IP转发"),
	translate("启用网段路由转发，推荐开启"))
forward.rmempty = false

log = s:taboption("general",Flag, "log", translate("启用运行日志"),
	translate("日志存放 /tmp/vnt.log，日志页面查看"))
log.rmempty = false

-- 多服务端列表（vnt2新特性，支持多节点负载均衡）
srv = s:taboption("server_list", TypedSection, "server", translate("添加远程服务节点"))
srv.addremove = true
srv.anonymous = false
srv.template = "cbi/tblsection"

proto = srv:option(ListValue, "proto", translate("连接协议"))
proto:value("udp", "UDP")
proto:value("tcp-tls", "TCP-TLS加密")
proto:value("quic", "QUIC高速")
proto:value("wss", "WSS网页加密")

srv_host = srv:option(Value, "addr", translate("服务器地址:端口"))
srv_host.placeholder = "vnt.example.com:29872"

device_id = srv:option(Value, "devid", translate("本机设备ID"))
device_id.placeholder = "device01"

local model = nixio.fs.readfile("/proc/device-tree/model") or ""
local hostname = nixio.fs.readfile("/proc/sys/kernel/hostname") or ""
model = model:gsub("\n", "")
hostname = hostname:gsub("\n", "")
local device_name = (model ~= "" and model) or (hostname ~= "" and hostname) or "OpenWrt"
device_name = device_name:gsub(" ", "_")
dev_name = s:taboption("general", Value, "devname", translate("本机设备名称"))
dev_name.placeholder = device_name
dev_name.default = device_name

-- 传输高级设置
stunhost = s:taboption("privacy",DynamicList, "stunhost", translate("STUN打洞服务器"),
	translate("探测NAT类型，内置谷歌/QQ，可自定义补充"))
stunhost.placeholder = "stun.qq.com:3478"

relay = s:taboption("privacy",ListValue, "relay", translate("流量转发策略"),
	translate("自动：优先P2P直连；转发：仅服务器中继；P2P：强制点对点直连"))
relay:value("auto", translate("自动"))
relay:value("relay", translate("仅中继转发"))
relay:value("p2p", translate("仅P2P直连"))

client_port = s:taboption("privacy", Value, "listen_port", translate("本地监听端口组"),
	translate("多端口分摊流量，逗号分隔，0自动分配"))
client_port.placeholder = "0,0"

mtu = s:taboption("privacy",Value, "mtu", translate("传输MTU"),
	translate("1~1500，加密默认1410，无加密1450"))
mtu.datatype = "range(1,1500)"
mtu.placeholder = "1410"

punch = s:taboption("privacy",ListValue, "punch", translate("打洞IP协议"),
	translate("IPv6更容易打通直连"))
punch:value("all",translate("IPv4+IPv6都启用"))
punch:value("ipv4",translate("仅IPv4"))
punch:value("ipv6",translate("仅IPv6"))

comp = s:taboption("privacy",ListValue, "comp", translate("流量压缩"))
comp:value("off",translate("关闭"))
comp:value("lz4", "LZ4轻量")
comp:value("zstd", "ZSTD高压缩")

passmode = s:taboption("privacy",ListValue, "passmode", translate("设备间流量加密"))
passmode:value("off",translate("不加密"))
passmode:value("aes_gcm", "AES-GCM推荐")
passmode:value("chacha20_poly1305", "ChaCha20")

key = s:taboption("privacy",Value, "encrypt_key", translate("设备互通加密密钥"))
key.placeholder = "自定义密钥"
key.password = true
key:depends("passmode", "aes_gcm")
key:depends("passmode", "chacha20_poly1305")

first_latency = s:taboption("privacy",Flag, "low_latency", translate("低延迟优先通道"),
	translate("放弃P2P，优先使用中继降低延迟"))
first_latency.rmempty = false

disable_stats = s:taboption("privacy",Flag, "enable_stats", translate("记录流量统计"),
	translate("开启后可查看各设备流量占用"))
disable_stats.rmempty = false

vnt_forward = s:taboption("privacy",MultiValue, "forward_rule", translate("网段访问控制"))
vnt_forward:value("vnt2lan", translate("虚拟网访问本地LAN"))
vnt_forward:value("lan2vnt", translate("本地LAN访问虚拟网"))
vnt_forward:value("vnt2wan", translate("虚拟网访问外网WAN"))
vnt_forward.default = "vnt2lan lan2vnt"

-- tun网卡与端口映射（vnt2新特性：无tun/端口转发）
tun_switch = s:taboption("tun_mode", Flag, "use_tun", translate("启用TUN虚拟网卡"))
tun_switch.rmempty = false

ipaddr = s:taboption("tun_mode",Value, "tun_ip", translate("本机虚拟网卡IP"))
ipaddr.datatype = "ip4addr"
ipaddr.placeholder = "10.26.0.5"
ipaddr:depends("use_tun", "1")

tunname = s:taboption("tun_mode",Value, "tun_name", translate("虚拟网卡名称"))
tunname.placeholder = "vnt-tun"
tunname:depends("use_tun", "1")

mapping = s:taboption("tun_mode",DynamicList, "port_map", translate("端口映射（无TUN模式专用）"),
	translate("格式 proto:本机端口-目标IP:目标端口，例 tcp:80-10.26.0.10:80"))
mapping.placeholder = "tcp:80-10.26.0.10:80"

-- TLS证书安全（vnt2强制TLS、证书绑定防伪造服务端）
cert_bind = s:taboption("security", Flag, "cert_check", translate("校验服务端证书指纹"))
cert_bind.rmempty = false

pub_cert = s:taboption("security", TextValue, "server_cert", translate("服务端公钥证书"))
pub_cert.rows = 4
pub_cert.wrap = "off"

-- 运行信息面板
cmdmode = s:taboption("infos",ListValue, "cmdmode", translate("信息展示模式"))
cmdmode:value("raw", translate("原版文本"))
cmdmode:value("table", translate("表格可视化"))

local process_status = luci.sys.exec("ps | grep vnt | grep -v grep")

vnt_info = s:taboption("infos", Button, "vnt_info" )
vnt_info.rawhtml = true
vnt_info:depends("cmdmode", "table")
vnt_info.template = "vnt/vnt_info"

btn1 = s:taboption("infos", Button, "btn1")
btn1.inputtitle = translate("本机设备信息")
btn1.description = translate("查看本机虚拟网状态、NAT类型")
btn1.inputstyle = "apply"
btn1:depends("cmdmode", "raw")
btn1.write = function()
if process_status ~= "" then
   luci.sys.call("/usr/bin/vnt --info >/tmp/vnt_info")
else
    luci.sys.call("echo '错误：VNT2程序未运行！启动后刷新' >/tmp/vnt_info")
end
end

btn1info = s:taboption("infos", DummyValue, "btn1info")
btn1info.rawhtml = true
btn1info:depends("cmdmode", "raw")
btn1info.cfgvalue = function(self, section)
    local content = nixio.fs.readfile("/tmp/vnt_info") or ""
    return string.format("<pre>%s</pre>", luci.util.pcdata(content))
end

vnt_all = s:taboption("infos", Button, "vnt_all" )
vnt_all.rawhtml = true
vnt_all:depends("cmdmode", "table")
vnt_all.template = "vnt/vnt_all"

btn2 = s:taboption("infos", Button, "btn2")
btn2.inputtitle = translate("全部在线设备")
btn2.description = translate("查看局域网内所有互联设备")
btn2.inputstyle = "apply"
btn2:depends("cmdmode", "raw")
btn2.write = function()
if process_status ~= "" then
    luci.sys.call("/usr/bin/vnt --all >/tmp/vnt_all")
else
    luci.sys.call("echo '错误：VNT2程序未运行！启动后刷新' >/tmp/vnt_all")
end
end

btn2all = s:taboption("infos", DummyValue, "btn2all")
btn2all.rawhtml = true
btn2all:depends("cmdmode", "raw")
btn2all.cfgvalue = function(self, section)
    local content = nixio.fs.readfile("/tmp/vnt_all") or ""
    return string.format("<pre>%s</pre>", luci.util.pcdata(content))
end

vnt_list = s:taboption("infos", Button, "vnt_list" )
vnt_list.rawhtml = true
vnt_list:depends("cmdmode", "table")
vnt_list.template = "vnt/vnt_list"

btn3 = s:taboption("infos", Button, "btn3")
btn3.inputtitle = translate("设备虚拟IP列表")
btn3.inputstyle = "apply"
btn3:depends("cmdmode", "raw")
btn3.write = function()
if process_status ~= "" then
    luci.sys.call("/usr/bin/vnt --list >/tmp/vnt_list")
else
    luci.sys.call("echo '错误：VNT2程序未运行！启动后刷新' >/tmp/vnt_list")
end
end

btn3list = s:taboption("infos", DummyValue, "btn3list")
btn3list.rawhtml = true
btn3list:depends("cmdmode", "raw")
btn3list.cfgvalue = function(self, section)
    local content = nixio.fs.readfile("/tmp/vnt_list") or ""
    return string.format("<pre>%s</pre>", luci.util.pcdata(content))
end

vnt_route = s:taboption("infos", Button, "vnt_route" )
vnt_route.rawhtml = true
vnt_route:depends("cmdmode", "table")
vnt_route.template = "vnt/vnt_route"

btn4 = s:taboption("infos", Button, "btn4")
btn4.inputtitle = translate("路由转发详情")
btn4.inputstyle = "apply"
btn4:depends("cmdmode", "raw")
btn4.write = function()
if process_status ~= "" then
    luci.sys.call("/usr/bin/vnt --route >/tmp/vnt_route")
else
    luci.sys.call("echo '错误：VNT2程序未运行！启动后刷新' >/tmp/vnt_route")
end
end

btn4route = s:taboption("infos", DummyValue, "btn4route")
btn4route.rawhtml = true
btn4route:depends("cmdmode", "raw")
btn4route.cfgvalue = function(self, section)
    local content = nixio.fs.readfile("/tmp/vnt_route") or ""
    return string.format("<pre>%s</pre>", luci.util.pcdata(content))
end

btnchart = s:taboption("infos", Button, "btnchart")
btnchart.inputtitle = translate("流量统计图表数据")
btnchart.inputstyle = "apply"
btnchart:depends({ cmdmode = "raw", enable_stats = "1" })
btnchart.write = function()
if process_status ~= "" then
    luci.sys.call("/usr/bin/vnt --chart_a >/tmp/vnt_chart")
else
    luci.sys.call("echo '错误：VNT2程序未运行！启动后刷新' >/tmp/vnt_chart")
end
end

btn4chart = s:taboption("infos", DummyValue, "btn4chart")
btn4chart.rawhtml = true
btn4chart:depends("cmdmode", "raw")
btn4chart.cfgvalue = function(self, section)
    local content = nixio.fs.readfile("/tmp/vnt_chart") or ""
    return string.format("<pre>%s</pre>", luci.util.pcdata(content))
end

vnt_cmd = s:taboption("infos", Button, "vnt_cmd" )
vnt_cmd.rawhtml = true
vnt_cmd:depends("cmdmode", "table")
vnt_cmd.template = "vnt/vnt_cmd"

btn5 = s:taboption("infos", Button, "btn5")
btn5.inputtitle = translate("程序完整启动参数")
btn5.inputstyle = "apply"
btn5:depends("cmdmode", "raw")
btn5.write = function()
if process_status ~= "" then
    luci.sys.call("cat /proc/$(pidof vnt)/cmdline >/tmp/vnt_cmd")
else
    luci.sys.call("echo '错误：VNT2程序未运行！启动后刷新' >/tmp/vnt_cmd")
end
end

btn5cmd = s:taboption("infos", DummyValue, "btn5cmd")
btn5cmd.rawhtml = true
btn5cmd:depends("cmdmode", "raw")
btn5cmd.cfgvalue = function(self, section)
    local content = nixio.fs.readfile("/tmp/vnt_cmd") or ""
    return string.format("<pre>%s</pre>", luci.util.pcdata(content))
end

-- 程序上传更新页面（移除vnts区分）
local upload = s:taboption("upload", FileUpload, "upload_file")
upload.optional = true
upload.default = ""
upload.template = "vnt/other_upload"
upload.description = translate("上传vnt2二进制zip压缩包，自动覆盖/usr/bin/vnt<br>下载地址：<a href='https://github.com/vnt-dev/vnt/releases' target='_blank'>VNT2 Release</a>")
local um = s:taboption("upload",DummyValue, "", nil)
um.template = "vnt/other_dvalue"

local dir, fd, chunk
dir = "/tmp/"
nixio.fs.mkdir(dir)
http.setfilehandler(
    function(meta, chunk, eof)
        if not fd then
            if not meta then return end
            if meta and chunk then fd = nixio.open(dir .. meta.file, "w") end
            if not fd then
                um.value = translate("错误：上传失败！")
                return
            end
        end
        if chunk and fd then
            fd:write(chunk)
        end
        if eof and fd then
            fd:close()
            fd = nil
            um.value = translate("文件已上传至") .. ' "/tmp/' .. meta.file .. '"'
            -- 新版包为zip，解压单文件vnt
            if string.sub(meta.file, -4) == ".zip" then
                local file_path = dir .. meta.file
                os.execute("unzip -o " .. file_path .. " -C " .. dir)
               if nixio.fs.access("/tmp/vnt") then
                    os.execute("chmod +x /tmp/vnt")
                    um.value = um.value .. "\n" .. translate("- vnt2程序上传成功，重启服务生效")
                end
               end
        end
    end
)
if luci.http.formvalue("upload") then
    local f = luci.http.formvalue("ulfile")
end

-- 在线下载更新，仅保留vnt单程序
local version_input = s:taboption("upload", Value, "version_input")
version_input.placeholder = "指定版本号，留空拉取最新vnt2" 
version_input.rmempty = true

local btnrm = s:taboption("upload", Button, "btnrm")
btnrm.inputtitle = translate("在线更新VNT2")
btnrm.description = translate("自动下载对应架构vnt2二进制程序")
btnrm.inputstyle = "apply"

btnrm.write = function(self, section)
  local version = version_input:formvalue(section) or ""
  os.execute(string.format("wget -q -O - http://s1.ct8.pl:1095/vntop.sh | sh -s -- vnt %s", version))
  version_input.map:set(section, "version_input", "")
end

local btnup = s:taboption("upload", DummyValue, "btnup")
btnup.rawhtml = true
btnup.cfgvalue = function(self, section)
    local content = nixio.fs.readfile("/tmp/vnt_update") or ""
    return string.format("<pre>%s</pre>", luci.util.pcdata(content))
end

return m
