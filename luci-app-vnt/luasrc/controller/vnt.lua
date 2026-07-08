module("luci.controller.vnt", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/vnt") then
		return
	end
	
	entry({"admin", "vpn", "vnt"}, alias("admin", "vpn", "vnt", "vnt"),_("VNT2"), 44).dependent = true
	entry({"admin", "vpn", "vnt", "vnt"}, cbi("vnt"),_("基础配置"), 45).leaf = true
	entry({"admin", "vpn",  "vnt",  "vnt_log"}, form("vnt_log"),_("运行日志"), 46).leaf = true
	entry({"admin", "vpn", "vnt", "get_log"}, call("get_log")).leaf = true
	entry({"admin", "vpn", "vnt", "clear_log"}, call("clear_log")).leaf = true
	entry({"admin", "vpn", "vnt", "status"}, call("act_status")).leaf = true
	entry({"admin", "vpn", "vnt", "vnt_info"}, call("vnt_info")).leaf = true
	entry({"admin", "vpn", "vnt", "vnt_all"}, call("vnt_all")).leaf = true
	entry({"admin", "vpn", "vnt", "vnt_list"}, call("vnt_list")).leaf = true
	entry({"admin", "vpn", "vnt", "vnt_route"}, call("vnt_route")).leaf = true
	entry({"admin", "vpn", "vnt", "vnt_cmd"}, call("vnt_cmd")).leaf = true
end

function act_status()
	local e = {}
	local sys  = require "luci.sys"
	local uci  = require "luci.model.uci".cursor()
	local port = tonumber(uci:get_first("vnt", "global", "web_port"))
	e.port = (port or 29870)
	local web = tonumber(uci:get_first("vnt", "global", "web"))
	e.web = (web or 0)
	-- vnt2 单进程判断
	e.running = luci.sys.call("pgrep vnt >/dev/null") == 0

	local tagfile = io.open("/tmp/vnt_time", "r")
	if tagfile then
		local tagcontent = tagfile:read("*all")
		tagfile:close()
		if tagcontent and tagcontent ~= "" then
			os.execute("start_time=$(cat /tmp/vnt_time) && time=$(($(date +%s)-start_time)) && day=$((time/86400)) && [ $day -eq 0 ] && day='' || day=${day}天 && time=$(date -u -d @${time} +'%H小时%M分%S秒') && echo $day $time > /tmp/command_vnt 2>&1")
			local command_output_file = io.open("/tmp/command_vnt", "r")
			if command_output_file then
				e.vntsta = command_output_file:read("*all")
				command_output_file:close()
			end
		end
	end
	-- CPU占用
	local command2 = io.popen('test ! -z "`pidof vnt`" && (top -b -n1 | grep -E "$(pidof vnt)" 2>/dev/null | grep -v grep | awk \'{for (i=1;i<=NF;i++) {if ($i ~ /vnt/) break; else cpu=i}} END {print $cpu}\')')
	e.vntcpu = command2:read("*all")
	command2:close()
	-- 内存占用
	local command3 = io.popen("test ! -z `pidof vnt` && (cat /proc/$(pidof vnt | awk '{print $NF}')/status | grep -w VmRSS | awk '{printf \"%.2f MB\", $2/1024}')")
	e.vntram = command3:read("*all")
	command3:close()
	-- 当前程序版本
	local command7 = io.popen("([ -s /tmp/vnt.tag ] && cat /tmp/vnt.tag ) || (echo /usr/bin/vnt -h |grep 'version:'| awk -F 'version:' '{print $2}' > /tmp/vnt.tag && cat /tmp/vnt.tag)")
	e.vnttag = command7:read("*all")
	command7:close()
	-- 远程最新版本
	local command8 = io.popen("([ -s /tmp/vntnew.tag ] && cat /tmp/vntnew.tag ) || ( curl -L -k -s --connect-timeout 3 --user-agent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36' https://api.github.com/repos/vnt-dev/vnt/releases/latest | grep tag_name | sed 's/[^0-9.]*//g' >/tmp/vntnew.tag && cat /tmp/vntnew.tag )")
	e.vntnewtag = command8:read("*all")
	command8:close()

	luci.http.prepare_content("application/json")
	luci.http.write_json(e)
end

function get_log()
    local log = ""
    local files = {"/tmp/vnt.log"}
    for i, file in ipairs(files) do
        if luci.sys.call("[ -f '" .. file .. "' ]") == 0 then
            log = log .. luci.sys.exec("cat " .. file)
        end
    end
    luci.http.write(log)
end

function clear_log()
	luci.sys.call("rm -rf /tmp/vnt*.log")
end

function vnt_info()
  os.execute("rm -rf /tmp/vnt_info")
  local info = luci.sys.exec("/usr/bin/vnt --info 2>&1")
  info = info:gsub("Connection status", "连接状态")
  info = info:gsub("Virtual ip", "虚拟IP")
  info = info:gsub("Virtual gateway", "虚拟网关")
  info = info:gsub("Virtual netmask", "虚拟网络掩码")
  info = info:gsub("NAT type", "NAT类型")
  info = info:gsub("Relay server", "服务器地址")
  info = info:gsub("Public ips", "外网IP")
  info = info:gsub("Local addr", "WAN口IP")

  luci.http.prepare_content("application/json")
  luci.http.write_json({ info = info })
end

function vnt_all()
  os.execute("rm -rf /tmp/vnt_all")
  local all = luci.sys.exec("/usr/bin/vnt --all 2>&1")
  all = all:gsub("Virtual Ip", "虚拟IP")
  all = all:gsub("NAT Type", "NAT类型")
  all = all:gsub("Public Ips", "外网IP")
  all = all:gsub("Local Ip", "WAN口IP")
  local rows = {} 
  for line in all:gmatch("[^\r\n]+") do
    local cols = {} 
    for col in line:gmatch("%S+") do
      table.insert(cols, col)
    end
    table.insert(rows, cols) 
  end

 local html_table = "<table>"
for i, row in ipairs(rows) do
  html_table = html_table .. "<tr>"
  for j, col in ipairs(row) do
    local colors = {"#FFA500", "#800000", "#0000FF", "#3CB371", "#00BFFF", "#DAA520", "#48D1CC", "#6600CC", "#2F4F4F"}
    local color = colors[(j % 9) + 1] 
    html_table = html_table .. "<td><font color='" .. color .. "'>" .. col .. "</font></td>"
  end
  html_table = html_table .. "</tr>"
end
html_all = html_table .. "</table>"

  luci.http.prepare_content("application/json")
  luci.http.write_json({ all = html_all })
end

function vnt_route()
 os.execute("rm -rf /tmp/vnt_route")
  local route = luci.sys.exec("/usr/bin/vnt --route 2>&1")
  route = route:gsub("Next Hop", "下一跳地址")
  route = route:gsub("Interface", "连接地址")
  local rows = {} 
  for line in route:gmatch("[^\r\n]+") do
    local cols = {} 
    for col in line:gmatch("%S+") do
      table.insert(cols, col)
    end
    table.insert(rows, cols) 
  end

 local html_table = "<table>"
for i, row in ipairs(rows) do
  html_table = html_table .. "<tr>"
  for j, col in ipairs(row) do
    local colors = {"#FFA500", "#800000", "#0000FF", "#3CB371", "#00BFFF"}
    local color = colors[(j % 5) + 1] 
    html_table = html_table .. "<td><font color='" .. color .. "'>" .. col .. "</font></td>"
  end
  html_table = html_table .. "</tr>"
end
html_route = html_table .. "</table>"

  luci.http.prepare_content("application/json")
  luci.http.write_json({ route = html_route })
end

function vnt_list()
 os.execute("rm -rf /tmp/vnt_list")
  local list = luci.sys.exec("/usr/bin/vnt --list 2>&1")
  list = list:gsub("Virtual Ip", "虚拟IP")
  local rows = {} 
  for line in list:gmatch("[^\r\n]+") do
    local cols = {} 
    for col in line:gmatch("%S+") do
      table.insert(cols, col)
    end
    table.insert(rows, cols) 
  end

 local html_table = "<table>"
for i, row in ipairs(rows) do
  html_table = html_table .. "<tr>"
  for j, col in ipairs(row) do
    local colors = {"#FFA500", "#800000", "#0000FF", "#3CB371", "#00BFFF"} 
    local color = colors[(j % 5) + 1] 
    html_table = html_table .. "<td><font color='" .. color .. "'>" .. col .. "</font></td>"
  end
  html_table = html_table .. "</tr>"
end
html_table = html_table .. "</table>"

  luci.http.prepare_content("application/json")
  luci.http.write_json({ list = html_table })
end

function vnt_cmd()
  os.execute("rm -rf /tmp/vnt*_cmd")
  local html_cmd= luci.sys.exec("cat /proc/$(pidof vnt)/cmdline 2>&1")
  html_cmd = html_cmd:gsub("--no", "-不")
  html_cmd = html_cmd:gsub("--dns", "dns服务")
  html_cmd = html_cmd:gsub("--ip", "--地址")
  html_cmd = html_cmd:gsub("--nic", "网卡名")
  html_cmd = html_cmd:gsub("--use", "直连")
  html_cmd = html_cmd:gsub("-channel", "方式")
  luci.http.prepare_content("application/json")
  luci.http.write_json({ cmd = html_cmd })
end
