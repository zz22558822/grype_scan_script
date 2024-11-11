#!/bin/bash

# 檢查系統更新
sudo apt update -y && sudo apt upgrade -y

# 檢查是否安裝 grype 若沒有則使用腳本安裝
if ! command -v grype &> /dev/null
then
  echo "grype 未安裝，正在使用安裝腳本安裝..."
  sudo curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sudo sh -s -- -b /usr/local/bin
else
  echo "grype 確認已安裝"
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

echo "-------------------------------------------------------------------"

# 列出所有本地 Docker 映像並掃描
sudo docker images --format "{{.Repository}}:{{.Tag}}" | while read image; do
  # 提取映像名稱（去除版本號和標籤）
  image_name=$(echo "$image" | cut -d ':' -f 1)
  current_date=$(date +%F)

  # 使用日期和映像名稱生成 JSON 檔案
  echo "正在掃描 ---> $image..."
  sudo grype "$image" -o json > "grype_scan_${current_date}_$(echo $image_name | sed 's/\//-/g').json"

  echo "-------------------------------------------------------------------"
  
  # 使用 jq 格式化 JSON 並轉換為 HTML 報告，加入 URL 按鈕
jq -r '.matches[] | .vulnerability | "\(.id) \(.severity) \(.description) \(.urls | join(" "))"' \
  "grype_scan_${current_date}_$(echo $image_name | sed 's/\//-/g').json" | \
  awk -v image_name="$image_name" -v current_date="$current_date" 'BEGIN {
            print "<html><head><title>Grype 漏洞報告</title><style>"
            print "body { font-family: Arial, sans-serif; padding: 20px; background-color: #f4f4f4; }"
            print "h1 { color: #333; }"
            print "table { width: 100%; border-collapse: collapse; margin-top: 20px; }"
            print "th, td { padding: 10px; text-align: left; border: 1px solid #ddd; }"
            print "th { background-color: #4CAF50; color: white; }"
            print "tr:nth-child(even) { background-color: #f2f2f2; }"
            print ".url-button-box { display: flex; justify-content: center; align-items: center; flex-direction: column; }"
            print ".url-button { width: 90%; margin: 2px; padding: 5px 10px; background-color: #0066cc; color: white; border: none; border-radius: 3px; cursor: pointer; }"
            print ".url-button:hover { background-color: #0079B3; }"
			print "</style></head><body>"
            print "<h1>Grype 漏洞報告 -- " image_name "</h1>"
            print "<h2>掃描日期: " current_date "</h2>"
            print "<table><thead><tr><th style=\"white-space:nowrap\">漏洞編號</th><th style=\"white-space:nowrap\">威脅級別</th><th>漏洞描述</th><th style=\"white-space:nowrap\">漏洞資訊</th></tr></thead><tbody>"
          }
          {
            severity = $2
            # 判斷威脅級別並翻譯成繁體中文，設置背景顏色
            if (severity == "Critical") {
                severity_cn = "嚴重 (Critical)"
                bg_color = "#FF3A3A" # 紅色
            } else if (severity == "High") {
                severity_cn = "高 (High)"
                bg_color = "#FF8C00" # 橙色
            } else if (severity == "Medium") {
                severity_cn = "中 (Medium)"
                bg_color = "#FFD700" # 黃色
            } else if (severity == "Low") {
                severity_cn = "低 (Low)"
                bg_color = "#90EE90" # 綠色
            } else if (severity == "Negligible") {
                severity_cn = "可忽略 (Negligible)"
                bg_color = "#ADD8E6" # 藍色
            } else {
                severity_cn = "未知 (Unknown)"
                bg_color = "#888888" # 灰色
            }
            # 使用 $1 (ID) 和 $2 (威脅級別)，剩下的所有內容作為描述
            description = ""
            urls = ""
            split($0, arr, " ")
            for (i = 3; i <= NF; i++) {
                if (arr[i] ~ /^http/) {
                    urls = urls "<button class=\"url-button\" onclick=\"window.open(\x27" arr[i] "\x27, \x27_blank\x27)\">連結</button>"
                } else {
                    description = description " " arr[i]
                }
            }
            print "<tr><td style=\"white-space:nowrap\">" $1 "</td><td style=\"white-space:nowrap; background-color:" bg_color "\">" severity_cn "</td><td>" description "</td><td><div class=\"url-button-box\">" urls "</div></td></tr>"
          }
          END { print "</tbody></table></body></html>" }' > "grype_scan_${current_date}_$(echo $image_name | sed 's/\//-/g').html"


  echo "產生報告: grype_scan_${current_date}_$(echo $image_name | sed 's/\//-/g').html"
  echo "-------------------------------------------------------------------"
done
