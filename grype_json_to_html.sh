#!/bin/bash

# 檢查是否有參數傳入，若有則使用該參數，否則請用戶手動輸入 JSON 檔案路徑
if [ -z "$1" ]; then
  read -p "請輸入 JSON 檔案的路徑: " json_path
else
  json_path="$1"
fi

# 檢查檔案是否存在
if [[ ! -f "$json_path" ]]; then
  echo "錯誤：檔案不存在，請確認路徑。"
  exit 1
fi

# 去掉 JSON 檔案的副檔名並生成 HTML 檔案名稱
html_report="${json_path%.*}.html"

# 設定目標資料夾名稱
target_folder="Grype_Report"

# 檢查資料夾是否存在，若不存在則創建它
if [ ! -d "$target_folder" ]; then
  echo "資料夾不存在，正在創建資料夾: $target_folder"
  mkdir "$target_folder"
  echo "-------------------------------------------------------------------"
fi
html_report="$target_folder/$(basename "$html_report")"

echo "-------------------------------------------------------------------"
echo "正在轉換 JSON >> HTML 報告中..."

# 開始生成 HTML 報告
echo "<html><head><title>Grype 漏洞報告</title><style>
      body { font-family: Arial, sans-serif; padding: 20px; background-color: #f4f4f4; }
      h1 { color: #333; }
      table { width: 100%; border-collapse: collapse; margin-top: 20px; }
      th, td { padding: 10px; text-align: left; border: 1px solid #ddd; }
      th { background-color: #4CAF50; color: white; }
      tr:nth-child(even) { background-color: #f2f2f2; }
      .url-button-box { display: flex; justify-content: center; align-items: center; flex-direction: column; }
      .url-button { width: 90%; margin: 2px; padding: 5px 10px; background-color: #0066cc; color: white; border: none; border-radius: 3px; cursor: pointer; }
      .url-button:hover { background-color: #0079B3; }
    </style></head><body>" > "$html_report"

echo "<h1>Grype 漏洞報告</h1>
      <h2>掃描日期: $(date +%F)</h2>
      <table><thead><tr><th style=\"white-space:nowrap\">漏洞編號</th><th style=\"white-space:nowrap\">威脅級別</th><th>漏洞描述</th><th style=\"white-space:nowrap\">漏洞資訊</th></tr></thead><tbody>" >> "$html_report"

# 使用 jq 處理 JSON，分別提取 id、severity、description 和 urls
jq -c '.matches[] | .vulnerability | {id, severity, description, urls}' "$json_path" | while read -r item; do
  id=$(echo "$item" | jq -r '.id')
  severity=$(echo "$item" | jq -r '.severity')
  description=$(echo "$item" | jq -r '.description')
  
  # 設置威脅級別的翻譯和背景顏色
  case $severity in
    "Critical") severity_cn="嚴重 (Critical)"; bg_color="#FF3A3A" ;;
    "High") severity_cn="高 (High)"; bg_color="#FF8C00" ;;
    "Medium") severity_cn="中 (Medium)"; bg_color="#FFD700" ;;
    "Low") severity_cn="低 (Low)"; bg_color="#90EE90" ;;
    "Negligible") severity_cn="可忽略 (Negligible)"; bg_color="#ADD8E6" ;;
    *) severity_cn="未知 (Unknown)"; bg_color="#888888" ;;
  esac

  # 處理 URL 按鈕
  urls=$(echo "$item" | jq -r '.urls[]' | while read -r url; do
    echo "<button class=\"url-button\" onclick=\"window.open('$url', '_blank')\">連結</button>"
  done | tr '\n' ' ')

  # 將資訊加入到表格中
  echo "<tr>
          <td style=\"white-space:nowrap\">$id</td>
          <td style=\"white-space:nowrap; background-color:$bg_color\">$severity_cn</td>
          <td>$description</td>
          <td><div class=\"url-button-box\">$urls</div></td>
        </tr>" >> "$html_report"
done

# 完成 HTML
echo "</tbody></table></body></html>" >> "$html_report"

echo "-------------------------------------------------------------------"
echo "報告已產出: $html_report"
echo "-------------------------------------------------------------------"
