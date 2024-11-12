#!/bin/bash

warning() {
	echo -e "\033[33m[南墙] $*\033[0m"
}

abort() {
	echo -e "\033[31m[南墙] $*\033[0m"
	exit 1
}

if [ -z "$BASH" ]; then
	abort "请用 bash 执行本脚本，参考最新的官方技术文档 https://waf.uusec.com/"
fi

if [ "$EUID" -ne "0" ]; then
	abort "请以 root 权限运行"
fi

SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd  "$SCRIPT_PATH"

if [ ! $(command -v docker) ]; then
	warning "未检测到Docker Engine，接下来帮您自动安装，过程较慢请耐心等待..."
	sh install-docker.sh --mirror Aliyun
	if [ $? -ne "0" ]; then
		abort "自动安装Docker Engine失败，请参考 https://help.aliyun.com/zh/ecs/use-cases/install-and-use-docker-on-a-linux-ecs-instance 手工安装后再执行本脚本"
	fi
	systemctl start docker && systemctl enable docker
fi

DC_CMD="docker compose"
$DC_CMD version > /dev/null 2>&1
if [ $? -ne "0" ]; then
	abort "你的Docker版本过低，缺少docker compose命令，请卸载后安装最新版本"
fi

stop_uuwaf(){
	$DC_CMD down
}

uninstall_uuwaf(){
	stop_uuwaf
	docker rm -f uuwaf wafdb > /dev/null 2>&1
	docker network rm wafnet > /dev/null 2>&1
	docker images|grep nanqiang|awk '{print $3}'|xargs docker rmi -f > /dev/null 2>&1
	docker volume ls|grep waf|awk '{print $2}'|xargs docker volume rm -f > /dev/null 2>&1
}

start_uuwaf(){
	if [ ! $(command -v netstat) ]; then
		$( command -v yum || command -v apt-get ) -y install net-tools
	fi
	port_status=`netstat -nlt|grep -E ':(80|443|4443)\s'|wc -l`
	if [ $port_status -gt 0 ]; then
		echo -e "\t 端口80、443、4443中的一个或多个被占用，请关闭对应服务或修改其端口"
		exit 1
	fi
	$DC_CMD up -d
}

update_uuwaf(){
	stop_uuwaf
	docker images|grep nanqiang|awk '{print $3}'|xargs docker rmi -f > /dev/null 2>&1
	docker volume ls|grep wafshared|awk '{print $2}'|xargs docker volume rm -f > /dev/null 2>&1
	start_uuwaf
}

restart_uuwaf(){
	stop_uuwaf
	start_uuwaf
}

clean_uuwaf(){
	docker system prune -a -f
	docker volume prune -a -f
}

start_menu(){
    clear
    echo "========================="
    echo "南墙Docker管理"
    echo "========================="
    echo "1. 启动"
    echo "2. 停止"
    echo "3. 重启"
    echo "4. 更新"
    echo "5. 卸载"
    echo "6. 清理"
    echo "7. 退出"
    echo
    read -p "请输入数字:" num
    case "$num" in
    	1)
	start_uuwaf
	echo "启动完成"
	;;
	2)
	stop_uuwaf
	echo "停止完成"
	;;
    	3)
	restart_uuwaf
	echo "重启完成"
	;;
	4)
	update_uuwaf
	echo "更新完成"
	;;
	5)
	uninstall_uuwaf
	echo "卸载完成"
	;;
	6)
	clean_uuwaf
	echo "清理完成"
	;;
	7)
	exit 1
	;;
	*)
	clear
	echo "请输入正确数字"
	;;
    esac
    sleep 3s
    start_menu
}

start_menu
