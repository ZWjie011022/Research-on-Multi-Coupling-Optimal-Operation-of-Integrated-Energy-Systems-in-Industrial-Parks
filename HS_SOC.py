import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

# ================= 1. 全局字体与格式设置 =================
plt.rcParams['font.sans-serif'] = ['SimSun']  # 宋体
plt.rcParams['axes.unicode_minus'] = False  # 正常显示负号

# 读取两个 Sheet 的数据
df_hourly = pd.read_excel('HS_SOC_Results_two.xlsx', sheet_name='Hourly_8760')
df_daily = pd.read_excel('HS_SOC_Results_two.xlsx', sheet_name='Daily_365')

hours = df_hourly['Hour'].values
soc_h = df_hourly['SOC_Hourly'].values

# 将 365 天的趋势点映射到 8760 小时的时间轴上 (每天的第1个小时)
days_x = (df_daily['Day'].values - 1) * 24 + 1
soc_d = df_daily['SOC_Trend'].values

# ================= 2. 创建画布与四季分割 =================
fig, ax = plt.subplots(figsize=(14, 6), dpi=300) # 画布稍微加高了一点，给外部图例留位置

# 定义四季边界
s1 = 91 * 24
s2 = (91 + 91) * 24
s3 = (91 + 91 + 91) * 24
s4 = 8760

# 添加四季背景色块 (低透明度莫兰迪色)
ax.axvspan(0,  s1, color='#98D294', alpha=0.15, label='_nolegend_') # 春
ax.axvspan(s1, s2, color='#FB8072', alpha=0.12, label='_nolegend_') # 夏
ax.axvspan(s2, s3, color='#FDC68A', alpha=0.15, label='_nolegend_') # 秋
ax.axvspan(s3, s4, color='#80B1D3', alpha=0.15, label='_nolegend_') # 冬

# 添加四季分割虚线
for x in [s1, s2, s3]:
    ax.axvline(x, color='#555555', linestyle='--', linewidth=1.2, alpha=0.8)

# 添加四季文字标签 (锁定在坐标轴外部一点点，绝对不会和曲线打架)
# transform=ax.get_xaxis_transform() 保证文字在 y=1.02 的位置始终贴着顶部边缘
ax.text(s1/2, 1.02, '春季', fontsize=14, fontweight='bold', ha='center', va='bottom', transform=ax.get_xaxis_transform(), color='#333333')
ax.text(s1 + (s2-s1)/2, 1.02, '夏季', fontsize=14, fontweight='bold', ha='center', va='bottom', transform=ax.get_xaxis_transform(), color='#333333')
ax.text(s2 + (s3-s2)/2, 1.02, '秋季', fontsize=14, fontweight='bold', ha='center', va='bottom', transform=ax.get_xaxis_transform(), color='#333333')
ax.text(s3 + (s4-s3)/2, 1.02, '冬季', fontsize=14, fontweight='bold', ha='center', va='bottom', transform=ax.get_xaxis_transform(), color='#333333')

# ================= 3. 绘制 SOC 曲线 =================
# 绘制微观 8760 小时波动
ax.fill_between(hours, soc_h, 0.05, color='#BEB8DA', alpha=0.6, label='_nolegend_')
ax.plot(hours, soc_h, color='#9A8EBA', linewidth=0.8, alpha=0.9, label='日内高频波动 (微观)')

# 绘制宏观 365 天趋势
ax.plot(days_x, soc_d, color='#E67E22', linewidth=2.5, marker='o', markersize=2,
        markerfacecolor='w', label='跨季节储能演变趋势 (宏观)')

# 绘制上下限约束红蓝虚线
ax.axhline(0.95, color='#E74C3C', linestyle='-.', linewidth=1.5, label='安全上限 $SOC_{max} = 0.95$')
ax.axhline(0.05, color='#3498DB', linestyle='-.', linewidth=1.5, label='安全下限 $SOC_{min} = 0.05$')

# ================= 4. 坐标轴与图例美化 =================
ax.set_xlim(1, 8760)
ax.set_ylim(0, 1.1)
ax.set_xticks(np.arange(0, 8761, 720))
ax.tick_params(direction='in', length=5, width=1)
ax.grid(axis='y', linestyle='--', alpha=0.4)

ax.set_xlabel('全年运行时间/h(1~8760)', fontsize=18, fontweight='bold')
ax.set_ylabel('长时氢储能 SOC', fontsize=16, fontweight='bold')

# 【修改点 1】：去掉了前面的“场景6：”，并且增加了 pad=50，给上方的图例腾出足够天空
ax.set_title('长时氢储能系统跨季节充放电演变轨迹', fontsize=16, fontweight='bold', pad=50)

# 【修改点 2】：把图例移到画布正上方外部 (y=1.08 的位置)，分成 2 列
ax.legend(loc='lower center', bbox_to_anchor=(0.5, 1.08), ncol=2, fontsize=15, edgecolor='#333333', framealpha=1)

plt.tight_layout()

# 保存高清图片
fig.savefig('氢储能跨季节SOC神图_定稿版.png', bbox_inches='tight', dpi=300)
print("恭喜！完美版氢储能神图已保存！")
# plt.show()