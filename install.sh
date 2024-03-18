#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Lỗi：${plain} File Này Chỉ Chỉ Sử Dụng Được Dưới User Root！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}Không Tìm Thấy Phiên Bản Hệ Thống，Vui Lòng Liên Hệ Với Admin Files！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="amd64"
    echo -e "${red}Không Phát Hiện Được Cấu Trúc，Sử Dụng Cấu Trúc Mặc Định: ${arch}${plain}"
fi

echo "架构: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ]; then
    echo "Công Cụ Này Không Hỗ Trợ 32 Bit (x86)，Vui Lòng Sử Dụng 64 Bit (x86_64)，Nếu Phát Hiện Không Chính Xác, Vui Lòng Liên Hệ Với Admin"
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Vui Lòng Sử Dụng VPS CentOS 7 Trở Lên！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Vui Lòng Sử Dụng VPS Ubuntu 16 Trở Lên！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Vui Lòng Sử Dụng VPS Debian 8 Hoặc Cao Hơn Của Hệ Thống！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar -y
    else
        apt install wget curl tar -y
    fi
}

#This function will be called when user installed x-ui out of sercurity
config_after_install() {
    echo -e "${yellow}Vì Lý Do Bảo Mật，Bạn Cần Thay Đổi Port Và Mật Khẩu Tài Khoản Sau Khi Hoàn Tất Cài Đặt/cập Nhật.${plain}"
    read -p "Xác Nhận Tiếp Tục?[y/n]": config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "Vui Lòng Đặt Tên Tài Khoản Của Bạn:" config_account
        echo -e "${yellow}Tên Tài Khoản Của Bạn Sẽ Được Đặt Thành:${config_account}${plain}"
        read -p "Vui Lòng Đặt Mật Khẩu Tài Khoản Của Bạn:" config_password
        echo -e "${yellow}Mật Khẩu Tài Khoản Của Bạn Sẽ Được Đặt Thành:${config_password}${plain}"
        read -p "Vui Lòng Đặt Port Truy Cập Bảng Điều Khiển:" config_port
        echo -e "${yellow}Port Truy Cập Bảng Điều Khiển Của Bạn Sẽ Được Đặt Thành:${config_port}${plain}"
        echo -e "${yellow}Xác Nhận Cài Đặt, Cài Đặt${plain}"
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password}
        echo -e "${yellow}Đã Hoàn Tất Cài Đặt Mật Khẩu Tài Khoản${plain}"
        /usr/local/x-ui/x-ui setting -port ${config_port}
        echo -e "${yellow}Đã Hoàn Tất Cài Đặt Port Bảng Điều Khiển${plain}"
    else
        echo -e "${red}Đã Hủy, Tất Cả Cài Đặt Là Cài Đặt Mặc Định, Vui Lòng Sửa Đổi Chúng Kịp Thời${plain}"
    fi
}

install_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/vaxilu/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Không Phát Hiện Được Phiên Bản X-ui. Có Thể Đã Vượt Quá Giới Hạn API Github. Vui Lòng Thử Lại Sau Hoặc Chỉ Định Phiên Bản X-ui Theo Cách Thủ Công Để Cài Đặt.${plain}"
            exit 1
        fi
        echo -e "Đã Phát Hiện Phiên Bản Mới Nhất Của X-ui：${last_version}，开始安装"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz https://github.com/vaxilu/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Không Tải Xuống Được X-ui, Vui Lòng Đảm Bảo Rằng Máy Chủ Của Bạn Có Thể Tải Xuống Các Tệp Github${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/vaxilu/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
        echo -e "开始安装 x-ui v$1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 x-ui v$1 失败，请确保此版本存在${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        rm /usr/local/x-ui/ -rf
    fi

    tar zxvf x-ui-linux-${arch}.tar.gz
    rm x-ui-linux-${arch}.tar.gz -f
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch}
    cp -f x-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/vaxilu/x-ui/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    config_after_install
    #echo -e "如果是全新安装，默认网页端口为 ${green}54321${plain}，用户名和密码默认都是 ${green}admin${plain}"
    #echo -e "请自行确保此端口没有被其他程序占用，${yellow}并且确保 54321 端口已放行${plain}"
    #    echo -e "若想将 54321 修改为其它端口，输入 x-ui 命令进行修改，同样也要确保你修改的端口也是放行的"
    #echo -e ""
    #echo -e "如果是更新面板，则按你之前的方式访问面板"
    #echo -e ""
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui v${last_version}${plain} Quá trình cài đặt hoàn tất và bảng điều khiển được bắt đầu，"
    echo -e ""
    echo -e "Cách Sử Dụng Lệnh Quản Lý X-ui: "
    echo -e "----------------------------------------------"
    echo -e "x-ui              - Hiển Thị Menu Quản Lý (Nhiều Chức Năng Hơn)"
    echo -e "x-ui start        - Bắt Đầu Bảng Điều Khiển X-ui"
    echo -e "x-ui stop         - Dừng Bảng Điều Khiển X-ui"
    echo -e "x-ui restart      - Khởi Động Lại Bảng X-ui"
    echo -e "x-ui status       - Xem Trạng Thái X-ui"
    echo -e "x-ui enable       - Đặt X-ui Tự Động Khởi Động Khi Khởi Động"
    echo -e "x-ui disable      - Hủy Tự Động Khởi Động X-ui Khi Khởi Động"
    echo -e "x-ui log          - Xem Nhật Ký X-ui"
    echo -e "x-ui v2-ui        - Di chuyển Dữ Liệu Tài Khoản V2-ui Của Máy Này Sang X-ui"
    echo -e "x-ui update       - Cập Nhật Bảng X-ui"
    echo -e "x-ui install      - Cài Đặt Bảng Điều Khiển X-ui"
    echo -e "x-ui uninstall    - Gỡ Cài Đặt Bảng X-ui"
    echo -e "----------------------------------------------"
}

echo -e "${green}开始安装${plain}"
install_base
install_x-ui $1
