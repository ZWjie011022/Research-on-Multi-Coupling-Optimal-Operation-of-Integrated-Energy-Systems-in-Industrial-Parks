import pandas as pd
import numpy as np
from sklearn.preprocessing import StandardScaler
from scipy.spatial import distance
import matplotlib.pyplot as plt

# ================= 核心排版参数修改 =================
# 设置中文字体为宋体，英文为 Times New Roman
plt.rcParams['font.sans-serif'] = ['SimSun', 'Times New Roman']
plt.rcParams['axes.unicode_minus'] = False

# 【关键修改1】将基础字号大幅提高到 20。
# 这样即便图片在 Word 中被缩小，视觉上依然能保持五号字左右的质感
plt.rcParams['font.size'] = 20
# 图例文字稍微小一丢丢，避免挡住图线
plt.rcParams['legend.fontsize'] = 16


# =================================================

def load_and_preprocess():
    # 1. 读取数据 (这里保持你原来的逻辑)
    pv_file = 'zhongwei_pv.csv'
    wind_file = 'zhongwei_wind.csv'

    df_pv = pd.read_csv(pv_file, skiprows=3)
    df_wind = pd.read_csv(wind_file, skiprows=3)

    # 2. 解析时间并提取日期和小时
    df_pv['local_time'] = pd.to_datetime(df_pv['local_time'])
    df_wind['local_time'] = pd.to_datetime(df_wind['local_time'])

    df_pv['date'] = df_pv['local_time'].dt.date
    df_pv['hour'] = df_pv['local_time'].dt.hour
    df_wind['date'] = df_wind['local_time'].dt.date
    df_wind['hour'] = df_wind['local_time'].dt.hour

    # 3. 转换为宽格式: 行是日期，列是0-23小时的出力
    pv_daily = df_pv.pivot(index='date', columns='hour', values='electricity')
    wind_daily = df_wind.pivot(index='date', columns='hour', values='electricity')

    pv_daily.columns = [f'pv_{h}' for h in pv_daily.columns]
    wind_daily.columns = [f'wind_{h}' for h in wind_daily.columns]

    df_daily = pd.concat([pv_daily, wind_daily], axis=1).dropna()
    return df_daily


def get_season(month):
    if month in [3, 4, 5]:
        return '春季'
    elif month in [6, 7, 8]:
        return '夏季'
    elif month in [9, 10, 11]:
        return '秋季'
    else:
        return '冬季'


def extract_seasonal_typical_days():
    df_daily = load_and_preprocess()

    df_daily['month'] = [d.month for d in df_daily.index]
    df_daily['season'] = df_daily['month'].apply(get_season)

    season_mapping = {
        '春季': '春季典型日',
        '夏季': '夏季典型日',
        '秋季': '秋季典型日',
        '冬季': '冬季典型日'
    }

    feature_cols = [c for c in df_daily.columns if c.startswith('pv_') or c.startswith('wind_')]
    scaler = StandardScaler()

    typical_days_info = {}

    # 【关键修改2】适当缩小物理画布尺寸，使得插入 Word 时不会被过度压缩
    plt.figure(figsize=(14, 10))

    for i, (season, typical_name) in enumerate(season_mapping.items()):
        season_data = df_daily[df_daily['season'] == season]
        X_raw = season_data[feature_cols].values
        dates = season_data.index.values

        if len(X_raw) == 0:
            continue

        X_scaled = scaler.fit_transform(X_raw)
        season_center_scaled = X_scaled.mean(axis=0)

        distances = [distance.euclidean(season_center_scaled, sample) for sample in X_scaled]
        medoid_idx = np.argmin(distances)

        typical_date = dates[medoid_idx]
        typical_profile_raw = X_raw[medoid_idx]

        typical_days_info[typical_name] = {
            'Date': typical_date,
            'Original_Season': season,
            'Profile': typical_profile_raw
        }

        print(f"{typical_name} (原{season}) 提取的真实日期为: {typical_date}")

        plt.subplot(2, 2, i + 1)

        for row in X_raw:
            plt.plot(range(24), row[:24], color='orange', alpha=0.08)
            plt.plot(range(24), row[24:], color='blue', alpha=0.08)

        # 加粗了典型日的线条，使其在 Word 中更显眼
        plt.plot(range(24), typical_profile_raw[:24], label=f'光伏', color='darkorange', linewidth=3, marker='o',
                 markersize=5)
        plt.plot(range(24), typical_profile_raw[24:], label=f'风电', color='navy', linewidth=3, marker='^',
                 markersize=5)

        plt.title(f"{typical_name}")
        plt.xlabel("时间/h")
        plt.ylabel("出力/kW")
        plt.xticks(range(0, 24, 4))  # 优化横坐标密度，防止字变大后拥挤
        plt.legend(loc='upper right')
        plt.grid(True, linestyle='--', alpha=0.5)

    # 优化子图之间的间距，防止大字体互相遮挡
    plt.tight_layout(pad=2.0)
    plt.savefig('seasonal_typical_days_output.png', dpi=300, bbox_inches='tight')
    plt.show()

    output_rows = []
    for typical_name, info in typical_days_info.items():
        row = {'Day_Type': typical_name, 'Real_Date': info['Date']}
        for h in range(24):
            row[f'PV_Hour_{h}'] = info['Profile'][h]
        for h in range(24):
            row[f'Wind_Hour_{h}'] = info['Profile'][24 + h]
        output_rows.append(row)

    df_output = pd.DataFrame(output_rows)
    df_output.to_csv('final_typical_days.csv', index=False, encoding='utf-8-sig')


if __name__ == "__main__":
    extract_seasonal_typical_days()
