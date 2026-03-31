import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.lines import Line2D
from matplotlib.patches import Patch

# =========================================================================
# 1. 全局学术图表样式设置 (严格宋体五号字标准)
# =========================================================================
# 中文使用宋体，英文/数字使用 Times New Roman
plt.rcParams['font.sans-serif'] = ['SimSun', 'Times New Roman']
plt.rcParams['font.family'] = 'sans-serif'
plt.rcParams['axes.unicode_minus'] = False

# 【核心】：全局字号死锁为 10.5pt (即标准五号字)
plt.rcParams['font.size'] = 10.5

C_BLUE = '#1F77B4'
C_RED = '#D62728'
C_YELLOW = '#F39C12'
C_GREEN = '#2CA02C'
C_PURPLE = '#8E44AD'
C_CYAN = '#17BECF'
C_TEAL = '#1ABC9C'

excel_file = 'Optimization_Results.xlsx'


# =========================================================================
# 2. 绘制 2x2 四维全息需求响应图
# =========================================================================
def plot_p4_2x2_holographic_dr(sheet_name='DR_Data'):
    print(f"正在绘制 {sheet_name} 的 2x2 四维全息图...")
    try:
        df = pd.read_excel(excel_file, sheet_name=sheet_name)
    except Exception as e:
        print(f"读取 Excel 失败: {e}")
        return

    t = df['Time']
    # 【物理尺寸】：宽度 6.3 英寸(满页宽)，高度 8.5 英寸(给顶部图例留出空间)
    fig, axes = plt.subplots(2, 2, figsize=(6.3, 7.2), dpi=300)

    # 统一子图绘制逻辑
    def plot_dr(ax, orig, opt, sl_in, sl_out, cut, title, color_opt, color_cut):
        ax.plot(t, orig, 'k--', linewidth=1.0)
        ax.plot(t, opt, color=color_opt, linewidth=1.5)
        ax.bar(t, sl_in, color=C_GREEN, alpha=0.75, edgecolor='none')
        ax.bar(t, -sl_out, color=C_YELLOW, alpha=0.75, edgecolor='none')
        ax.bar(t, -cut, bottom=-sl_out, color=color_cut, alpha=0.75, edgecolor='none')

        # 移除局部 fontsize，全部继承全局 10.5pt
        ax.set_title(title, fontweight='bold', pad=10)
        ax.set_xlabel('时间 / h')
        ax.set_ylabel('功率 / kW')
        ax.set_xlim(0, 25)
        ax.set_xticks(np.arange(0, 25, 4))  # 每 4 小时一个刻度，防止拥挤
        ax.grid(True, linestyle=':', alpha=0.6)

    # (1) 电负荷 [0,0]
    plot_dr(axes[0, 0], df['Load_E'], df['Load_E_DR'],
            df['P_E_sl_in'], df['P_E_sl_out'], df['P_E_cut'],
            'a. 电负荷需求响应', C_BLUE, C_RED)

    # (2) 热负荷 [0,1]
    plot_dr(axes[0, 1], df['Load_H'], df['Load_H_DR'],
            df['P_H_sl_in'], df['P_H_sl_out'], df['P_H_cut'],
            'b. 热负荷需求响应', C_RED, C_BLUE)

    # (3) 冷负荷 [1,0]
    plot_dr(axes[1, 0], df['Load_C'], df['Load_C_DR'],
            df['P_C_sl_in'], df['P_C_sl_out'], df['P_C_cut'],
            'c. 冷负荷需求响应', C_CYAN, C_PURPLE)

    # (4) 数据中心 [1,1]
    ax_dc = axes[1, 1]
    ax_dc.plot(t, df['Load_DC'], 'k--', linewidth=1.0)
    ax_dc.plot(t, df['Load_DC_opt'], '-s', color=C_PURPLE, linewidth=1.5, markersize=3, markerfacecolor='w')

    ax_dc_tw = ax_dc.twinx()
    ax_dc_tw.bar(t, df['Shift_in_DC'], color=C_TEAL, alpha=0.75, width=0.6)
    ax_dc_tw.bar(t, -df['Shift_out_DC'], color=C_YELLOW, alpha=0.75, width=0.6)

    ax_dc_tw.set_ylabel('算力时空转移量 / kW')
    ax_dc_tw.set_ylim(-df['Load_DC'].max() * 0.4, df['Load_DC'].max() * 0.4)
    ax_dc.set_title('d. 数据中心时序延迟响应', fontweight='bold', pad=10)
    ax_dc.set_xlabel('时间 / h')
    ax_dc.set_ylabel('算力负荷功率 / kW')
    ax_dc.set_xlim(0, 25)
    ax_dc.set_xticks(np.arange(0, 25, 4))
    ax_dc.grid(True, linestyle=':', alpha=0.6)

    # ------------------------------------------------------------------
    # 3. 顶部统一图例设置
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
               marker='s', markersize=3, markerfacecolor='w', label='最终优化算力'),
        Patch(facecolor=C_TEAL, alpha=0.75, label='延迟算力转入'),
        Patch(facecolor=C_YELLOW, alpha=0.75, label='算力推迟转出'),
    ]

    all_handles = shared_handles + specific_handles + dc_handles

    # 【关键修改】：将子图下移，给顶部留出空间 (top=0.78)
    plt.subplots_adjust(top=0.78, bottom=0.08, hspace=0.4, wspace=0.35)

    # 图例改为 3 列排布，放在最顶部
    fig.legend(
        handles=all_handles,
        loc='upper center',
        ncol=3,
        bbox_to_anchor=(0.5, 0.98),
        frameon=True,
        shadow=False,
        edgecolor='#333333',
        columnspacing=1.0,
        handlelength=1.5,
    )

    plt.savefig('P4_2x2_Holographic_DR.png', dpi=300, bbox_inches='tight')
    plt.show()


if __name__ == '__main__':
    plot_p4_2x2_holographic_dr()