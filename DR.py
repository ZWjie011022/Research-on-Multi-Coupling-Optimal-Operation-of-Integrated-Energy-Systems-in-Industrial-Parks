import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.lines import Line2D
from matplotlib.patches import Patch

# =========================================================================
# 1. 全局学术图表样式设置 (严格宋体五号字标准)
# =========================================================================
plt.rcParams['font.sans-serif'] = ['SimSun', 'Times New Roman']  # 中文宋体，英文新罗马
plt.rcParams['font.family'] = 'sans-serif'
plt.rcParams['axes.unicode_minus'] = False

# 【核心】：全局字号死锁为 10.5pt，即标准五号字
plt.rcParams['font.size'] = 10.5

C_BLUE = '#1F77B4'
C_RED = '#D62728'
C_YELLOW = '#F39C12'
C_GREEN = '#2CA02C'
C_PURPLE = '#8E44AD'
C_CYAN = '#17BECF'
C_TEAL = '#1ABC9C'

excel_file = 'DR_Results_All_Scenarios.xlsx'


# =========================================================================
# 任务 A：2x2 四维全息需求响应图
# =========================================================================
def plot_2x2_holographic_dr(sheet_name='S3_TSRO'):
    print(f"正在绘制 {sheet_name} 的 2x2 四维全息图...")
    try:
        df = pd.read_excel(excel_file, sheet_name=sheet_name)
    except Exception as e:
        print(f"读取 Excel 失败，请检查文件 {excel_file} 是否存在。")
        return

    t = df['Time']
    # 【核心尺寸】：宽度6.3英寸(满页宽)，高度7.5英寸
    fig, axes = plt.subplots(2, 2, figsize=(6.3, 7.5), dpi=300)

    def plot_dr(ax, orig, opt, sl_in, sl_out, cut, title, color_opt, color_cut):
        # 线宽适度调细，匹配五号字的精致感
        ax.plot(t, orig, 'k--', linewidth=1.0)
        ax.plot(t, opt, color=color_opt, linewidth=1.5)
        ax.bar(t, sl_in, color=C_GREEN, alpha=0.75, edgecolor='none')
        ax.bar(t, -sl_out, color=C_YELLOW, alpha=0.75, edgecolor='none')
        ax.bar(t, -cut, color=color_cut, alpha=0.75, edgecolor='none')

        # 移除局部 fontsize，全部继承 10.5pt
        ax.set_title(title, fontweight='bold')
        ax.set_xlabel('时间 / h')
        ax.set_ylabel('功率 / kW')
        ax.set_xlim(0, 25)
        # 横坐标改为每 4 小时一个刻度，防止 10.5pt 字体拥挤
        ax.set_xticks(np.arange(0, 25, 4))
        ax.grid(True, linestyle=':', alpha=0.6)

    # (1) 电负荷 [0,0]
    plot_dr(axes[0, 0], df['E_Orig'], df['E_Opt'],
            df['E_In'], df['E_Out'], df['E_Cut'],
            'a. 电负荷需求响应', C_BLUE, C_RED)

    # (2) 热负荷 [0,1]
    plot_dr(axes[0, 1], df['H_Orig'], df['H_Opt'],
            df['H_In'], df['H_Out'], df['H_Cut'],
            'b. 热负荷需求响应', C_RED, C_BLUE)

    # (3) 冷负荷 [1,0]
    plot_dr(axes[1, 0], df['C_Orig'], df['C_Opt'],
            df['C_In'], df['C_Out'], df['C_Cut'],
            'c. 冷负荷需求响应', C_CYAN, C_PURPLE)

    # (4) 数据中心 [1,1]
    ax_dc = axes[1, 1]
    ax_dc.plot(t, df['DC_Orig'], 'k--', linewidth=1.0)
    ax_dc.plot(t, df['DC_Opt'], '-s', color=C_PURPLE, linewidth=1.5, markersize=4, markerfacecolor='w')

    ax_dc_tw = ax_dc.twinx()
    ax_dc_tw.bar(t, df['DC_In'], color=C_TEAL, alpha=0.75, width=0.6)
    ax_dc_tw.bar(t, -df['DC_Out'], color=C_YELLOW, alpha=0.75, width=0.6)

    ax_dc_tw.set_ylabel('算力时空转移量 / kW')
    ax_dc_tw.set_ylim(-df['DC_Orig'].max() * 0.4, df['DC_Orig'].max() * 0.4)
    ax_dc.set_title('d. 数据中心算力时序延迟响应', fontweight='bold')
    ax_dc.set_xlabel('时间 / h')
    ax_dc.set_ylabel('算力负荷功率 / kW')
    ax_dc.set_xlim(0, 25)
    ax_dc.set_xticks(np.arange(0, 25, 4))
    ax_dc.grid(True, linestyle=':', alpha=0.6)

    # ------------------------------------------------------------------
    # 图例 (线宽同步改小)
    # ------------------------------------------------------------------
    shared_handles = [
        Line2D([0], [0], color='k', linestyle='--', linewidth=1.0, label='原始预测负荷'),
        Patch(facecolor=C_GREEN, alpha=0.75, label='柔性负荷转入'),
        Patch(facecolor=C_YELLOW, alpha=0.75, label='柔性负荷转出'),
    ]
    specific_handles = [
        Line2D([0], [0], color=C_BLUE, linewidth=1.5, label='优化响应负荷 (电)'),
        Line2D([0], [0], color=C_RED, linewidth=1.5, label='优化响应负荷 (热)'),
        Line2D([0], [0], color=C_CYAN, linewidth=1.5, label='优化响应负荷 (冷)'),
        Patch(facecolor=C_RED, alpha=0.75, label='极值负荷削减 (电)'),
        Patch(facecolor=C_BLUE, alpha=0.75, label='极值负荷削减 (热)'),
        Patch(facecolor=C_PURPLE, alpha=0.75, label='极值负荷削减 (冷)'),
    ]
    dc_handles = [
        Line2D([0], [0], color=C_PURPLE, linewidth=1.5,
               marker='s', markersize=4, markerfacecolor='w', label='最终优化算力'),
        Patch(facecolor=C_TEAL, alpha=0.75, label='延迟算力转入'),
        Patch(facecolor=C_YELLOW, alpha=0.75, label='算力推迟转出'),
    ]

    all_handles = shared_handles + specific_handles + dc_handles

    # 【关键修改】：释放底部空间，改在顶部留白 (top=0.78)
    plt.subplots_adjust(top=0.78, bottom=0.1, wspace=0.3, hspace=0.4)

    # 【关键修改】：图例放到顶部中心 (upper center)，紧贴子图
    fig.legend(
        handles=all_handles,
        loc='upper center',
        ncol=3,
        bbox_to_anchor=(0.5, 0.99),  # 放在画布最上方
        frameon=True,
        shadow=False,
        edgecolor='#333333',
        columnspacing=1.0,
        handlelength=1.5,
    )

    plt.savefig(f'{sheet_name}_2x2_Holographic_DR.png', dpi=300, bbox_inches='tight')
    plt.show()


# =========================================================================
# 任务 B：四种场景需求响应动作总量对比柱状图
# =========================================================================
def plot_scenario_comparison():
    print("正在绘制四场景需求响应动作对比图...")
    sheets = ['S1_Det_Base', 'S2_Det_DC', 'S3_TSRO', 'S4_DD_DRO']
    labels = ['场景1\n(仅常规DR)', '场景2\n(+数据中心DR)', '场景3\n(TSRO)', '场景4\n(DD-DRO)']

    total_cut, total_shift, total_dc_delay = [], [], []

    for s in sheets:
        try:
            df = pd.read_excel(excel_file, sheet_name=s)
            total_cut.append(df['E_Cut'].sum() + df['H_Cut'].sum() + df['C_Cut'].sum())
            total_shift.append(df['E_In'].sum() + df['H_In'].sum() + df['C_In'].sum())
            total_dc_delay.append(df['DC_Out'].sum() if s != 'S1_Det_Base' else 0)
        except Exception:
            total_cut.append(0);
            total_shift.append(0);
            total_dc_delay.append(0)

    x = np.arange(len(labels))
    width = 0.22

    # 【核心尺寸】：宽度 6.3 英寸，高度 4.5 英寸
    fig, ax = plt.subplots(figsize=(6.3, 4.5), dpi=300)

    rects1 = ax.bar(x - width, total_cut, width, label='全天削减总电量(常规负荷)',
                    color=C_RED, alpha=0.85, edgecolor='black', linewidth=0.5)
    rects2 = ax.bar(x, total_shift, width, label='全天平移总电量(常规负荷)',
                    color=C_BLUE, alpha=0.85, edgecolor='black', linewidth=0.5)
    rects3 = ax.bar(x + width, total_dc_delay, width, label='数据中心算力延迟总电量',
                    color=C_PURPLE, alpha=0.85, edgecolor='black', linewidth=0.5)

    # 移除局部 fontsize
    ax.set_ylabel('需求响应功率 / kWh', fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(labels)
    # 图例改为 2 列，防止越界
    ax.legend(loc='upper center', bbox_to_anchor=(0.5, 1.22),
              ncol=2, framealpha=0.9, edgecolor='#333333')
    ax.grid(axis='y', linestyle='--', alpha=0.6)
    ax.set_axisbelow(True)

    def autolabel(rects):
        for rect in rects:
            height = rect.get_height()
            if height > 0:
                ax.annotate(f'{int(height)}',
                            xy=(rect.get_x() + rect.get_width() / 2, height),
                            xytext=(0, 3), textcoords="offset points",
                            ha='center', va='bottom',
                            fontweight='bold', color='#333333')  # 移除局部 fontsize

    autolabel(rects1);
    autolabel(rects2);
    autolabel(rects3)
    ax.set_ylim(0, max(max(total_cut), max(total_shift), max(total_dc_delay)) * 1.18)

    plt.tight_layout()
    plt.savefig('DR_Scenarios_Comparison_Pro.png', dpi=300, bbox_inches='tight')
    plt.show()


if __name__ == '__main__':
    plot_2x2_holographic_dr('S3_TSRO')
    plot_scenario_comparison()