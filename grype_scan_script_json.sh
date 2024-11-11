#!/bin/bash

# 檢查系統更新
sudo apt update -y && sudo apt upgrade -y

# 檢查是否安裝 grype 若沒有則使用腳本安裝
if ! command -v grype &> /dev/null
then
  echo "grype 未安裝，正在使用安裝腳本安裝..."
  sudo curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sudo sh -s -- -b /usr/local/bin
else
  echo "grype 已經安裝"
fi

# 檢查 Docker 是否安裝
if ! command -v docker &> /dev/null
then
  echo "Docker 未安裝，請安裝 Docker 後再執行此腳本。"
  exit 1
fi

# 檢查是否有本地 Docker 映像
if [ "$(sudo docker images -q)" == "" ]; then
  echo "未找到任何本地 Docker 映像，請先拉取映像。"
  exit 1
fi

# 列出所有本地 Docker 映像
# sudo docker images --format "{{.Repository}}:{{.Tag}}"

# 列出所有本地 Docker 映像並掃描
sudo docker images --format "{{.Repository}}:{{.Tag}}" | while read image; do
  # 提取本地 Docker 映像名稱（去除版本號和標籤）
  image_name=$(echo "$image" | cut -d ':' -f 1)

  # 使用日期和映像名稱生成檔案名
  echo "正在掃描 ---> $image..."
  sudo grype "$image" -o json > "grype_scan_$(date +%F)_$(echo $image_name | sed 's/\//-/g').json"
done
