#!/bin/bash

# 提示用戶輸入 JSON 文件路徑
echo "請輸入 JSON 文件的名稱或路徑："
read json_file

# 檢查 JSON 文件是否存在
if [ ! -f "$json_file" ]; then
  echo "找不到 JSON 文件: $json_file"
  exit 1
fi

# 提取當前日期
current_date=$(date +%F)

# 提取文件名（去除路徑和副檔名）
base_name=$(basename "$json_file" .json)

# 使用 jq 格式化 JSON 並轉換為 HTML 報告，加入 URL 按鈕
jq -r '.matches[] | .vulnerability | "\(.id) \(.severity) \(.description) \(.urls | join(" "))"' "$json_file" | \
awk -v base_name="$base_name" -v current_date="$current_date" 'BEGIN {
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
            print "<h1>Grype 漏洞報告 -- " base_name "</h1>"
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
          END { print "</tbody></table></body></html>" }' > "${base_name}_${current_date}.html"

echo "報告已產生: ${base_name}_${current_date}.html"
