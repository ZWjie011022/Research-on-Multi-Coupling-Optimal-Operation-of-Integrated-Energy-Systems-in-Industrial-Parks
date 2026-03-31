import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.lines import Line2D
from matplotlib.patches import Patch

# ==========================================
# 1. 学术图表全局设置 (严格宋体五号字标准)
# ==========================================
plt.rcParams['font.sans-serif'] = ['SimSun', 'Times New Roman']  # 中文宋体，英文新罗马
plt.rcParams['axes.unicode_minus'] = False

# 【核心设置】：全局字号死锁为 10.5pt，即标准五号字
plt.rcParams['font.size'] = 10.5

file_path = 'Power_Balance_4Scenarios.xlsx'
sheets = ['S1', 'S2', 'S3', 'S4']
scenario_titles = ['场景一：确定性调度', '场景二：计及DC响应', '场景三：两阶段鲁棒', '场景四：分布鲁棒']

# 颜色配置 (保持不变)
colors_supply = {'P_Grid_Buy': '#E63946', 'P_PV': '#FFB703', 'P_Wind': '#219EBC', 'P_ESS_Dis': '#8CB369',
                 'P_HFC_e': '#9B5DE5'}
colors_demand = {'P_ESS_Ch': '#457B9D', 'P_EC': '#A8DADC', 'P_EL': '#F4A261', 'P_EB': '#BC6C25'}

# ==========================================
# 2. 开始绘制
# ==========================================
# 【尺寸核心】：宽度 6.3 英寸(满页宽)，高度 6.5 英寸
fig, axes = plt.subplots(2, 2, figsize=(6.3, 6.5), sharex=True, sharey=True, dpi=300)

# 【留白核心】：增加了 top 的留白 (top=0.78)，防止加了方框后的图例显得挤
fig.subplots_adjust(hspace=0.28, wspace=0.12, top=0.80, bottom=0.08)

supply_cols = ['P_Grid_Buy', 'P_PV', 'P_Wind', 'P_ESS_Dis', 'P_HFC_e']
demand_cols = ['P_ESS_Ch', 'P_EC', 'P_EL', 'P_EB']
legend_labels = ['主网购电', '光伏出力', '风电出力', '电储放电', '燃料电池', '电储充电', '电制冷机', '电解槽耗电',
                 '电锅炉耗电', '总电负荷']

for i, (sheet, title) in enumerate(zip(sheets, scenario_titles)):
    ax = axes[i // 2, i % 2]
    df = pd.read_excel(file_path, sheet_name=sheet)
    t = df['Time']

    # 供给侧
    bottom_pos = np.zeros(24)
    for col in supply_cols:
        ax.bar(t, df[col], bottom=bottom_pos, color=colors_supply[col], edgecolor='white', linewidth=0.3, width=0.8)
        bottom_pos += df[col]

    # 消耗侧 (镜像)
    bottom_neg = np.zeros(24)
    for col in demand_cols:
        ax.bar(t, -df[col], bottom=bottom_neg, color=colors_demand[col], edgecolor='white', linewidth=0.3, width=0.8)
        bottom_neg -= df[col]

    # 总负荷曲线 (精致圆点)
    ax.plot(t, df['P_Load_Total'], color='black', marker='o', markersize=3.5, linewidth=1.2,
            markeredgecolor='black', markerfacecolor='white')

    # 统一宋体五号字 (不单独放大)
    ax.set_title(title, fontweight='bold', pad=10)
    ax.grid(axis='y', linestyle='--', alpha=0.4)
    ax.set_xlim(0, 25)

    # 刻度每 4 小时一标
    ax.set_xticks(range(0, 25, 4))

    ax.axhline(0, color='black', linewidth=0.8)
    if i >= 2: ax.set_xlabel('时间 / h', fontweight='bold')
    if i % 2 == 0: ax.set_ylabel('功率 / kW', fontweight='bold')

# 【图例回路核心点】：手动构建，圆点改小至4pt，配合大画布
legend_elements = [Patch(facecolor=colors_supply[c], edgecolor='white') for c in supply_cols] + \
                  [Patch(facecolor=colors_demand[c], edgecolor='white') for c in demand_cols] + \
                  [Line2D([0], [0], color='black', marker='o', markerfacecolor='white', markersize=4, linewidth=1.2)]

# =========================================================================
# 🔥 【关键修改点】🔥：把图例的方框给加上
# =========================================================================
fig.legend(legend_elements, legend_labels, loc='upper center', ncol=5,
           handlelength=1.5,
           handleheight=1.0,
           handletextpad=0.4,
           columnspacing=1.0,

           # 【修正是这里】开启方框，设置灰色边框，关闭阴影
           frameon=True,
           shadow=False,
           edgecolor='#333333',
           facecolor='white',

           bbox_to_anchor=(0.5, 0.94))  # 稳稳落在顶部

plt.savefig('Full_Scenarios_TopLegend.png', dpi=300, bbox_inches='tight')
plt.show()

print("✅ 图例的方框已成功加上，所有字体均已完美适配为标准宋体五号字，图片已保存。")