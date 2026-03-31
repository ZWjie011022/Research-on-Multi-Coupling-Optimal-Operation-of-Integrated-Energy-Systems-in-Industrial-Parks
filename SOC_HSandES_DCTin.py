import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

# ==========================================
# 1. 学术图表全局设置 (严格宋体五号字标准)
# ==========================================
plt.rcParams['font.sans-serif'] = ['SimSun', 'Times New Roman']  # 中文宋体，英文新罗马
plt.rcParams['axes.unicode_minus'] = False

# 【核心修改 1】：全局字号死锁为 10.5pt，即标准五号字
plt.rcParams['font.size'] = 10.5

file_path = 'Storage_Temperature_Synergy.xlsx'


def plot_synergy_graph():
    print("正在读取数据并绘制异质储能与温控协同图...")
    try:
        df = pd.read_excel(file_path, sheet_name='Synergy_Data')
    except Exception as e:
        print(f"读取 Excel 失败，请检查文件 {file_path} 是否存在。")
        return

    t = df['Time'].values
    soc_es = df['SOC_ES'].values * 100  # 转化为百分比
    soc_hs = df['SOC_HS'].values * 100  # 转化为百分比
    t_in = df['T_in'].values

    # 【核心修改 2】：画布宽度设为 6.3 英寸(A4满页宽)，高度设为 4.5 英寸
    fig, ax1 = plt.subplots(figsize=(6.3, 4.5), dpi=300)

    # ==========================================
    # 2. 绘制分时电价背景阴影 (峰-平-谷)
    # ==========================================
    # 峰电时段 (红)
    ax1.axvspan(8.5, 11.5, facecolor='#FF9999', alpha=0.2, label='峰电时段 (0.95元)')
    ax1.axvspan(14.5, 21.5, facecolor='#FF9999', alpha=0.2)
    # 平电时段 (黄)
    ax1.axvspan(6.5, 8.5, facecolor='#FFFACD', alpha=0.4, label='平电时段 (0.60元)')
    ax1.axvspan(11.5, 14.5, facecolor='#FFFACD', alpha=0.4)
    ax1.axvspan(21.5, 22.5, facecolor='#FFFACD', alpha=0.4)
    # 谷电时段 (绿)
    ax1.axvspan(0.5, 6.5, facecolor='#E0F8E0', alpha=0.5, label='谷电时段 (0.29元)')
    ax1.axvspan(22.5, 24.5, facecolor='#E0F8E0', alpha=0.5)

    # ==========================================
    # 3. 左 Y 轴：实体储能 SOC (电储能 + 氢储能)
    # ==========================================
    # 去除局部 fontsize，继承全局五号字
    ax1.set_xlabel('时间 / h', fontweight='bold')
    ax1.set_ylabel('储能 SOC / %', fontweight='bold')

    # 【核心修改 3】：线宽和标记点适度调细，匹配精致的 6.3 英寸画布
    line1, = ax1.plot(t, soc_es, color='#1F77B4', marker='s', markersize=4, linewidth=1.5,
                      markerfacecolor='w', label='电储能 SOC (ES)')
    line2, = ax1.plot(t, soc_hs, color='#2CA02C', marker='o', markersize=4, linewidth=1.5,
                      markerfacecolor='w', label='氢储能 SOC (HS)')

    ax1.set_xlim(0.5, 24.5)
    # 若觉得每2小时一标太挤，可改为 range(0, 25, 4)
    ax1.set_xticks(range(2, 25, 2))
    ax1.set_ylim(0, 100)
    ax1.grid(axis='y', linestyle='--', alpha=0.5)

    # ==========================================
    # 4. 右 Y 轴：虚拟储能 (机房温度 T_in)
    # ==========================================
    ax2 = ax1.twinx()
    ax2.set_ylabel('数据中心机房温度 / ℃', fontweight='bold', color='#D62728')

    line3, = ax2.plot(t, t_in, color='#D62728', marker='^', markersize=4.5, linewidth=1.5,
                      markerfacecolor='w', label='机房温度 (T_in)')

    ax2.set_ylim(15, 30)
    ax2.tick_params(axis='y', labelcolor='#D62728')

    ax2.axhline(27.22, color='#D62728', linestyle='--', linewidth=1.2, alpha=0.7)
    ax2.axhline(17.78, color='#1F77B4', linestyle='--', linewidth=1.2, alpha=0.7)

    # 去除局部 fontsize，直接使用默认 10.5pt
    ax2.text(1, 27.5, '温度上限 27.22℃', color='#D62728', fontweight='bold')
    ax2.text(1, 16.8, '温度下限 17.78℃', color='#1F77B4', fontweight='bold')

    # ==========================================
    # 5. 图例合并与排版
    # ==========================================
    handles1, labels1 = ax1.get_legend_handles_labels()
    handles2, labels2 = ax2.get_legend_handles_labels()

    # 【核心修改 4】：通过 subplots_adjust 给上下图例腾出完美的物理留白
    plt.subplots_adjust(top=0.86, bottom=0.20)

    # 顶部图例 (背景色带)
    fig.legend(handles1[:3], labels1[:3], loc='upper center', bbox_to_anchor=(0.5, 0.98),
               ncol=3, frameon=False, columnspacing=1.5)

    # 底部图例 (折线)
    fig.legend(handles1[3:] + handles2, labels1[3:] + labels2, loc='lower center',
               bbox_to_anchor=(0.5, 0.02), ncol=3, frameon=False, columnspacing=1.5, handlelength=1.5)

    # 导出高清图
    plt.savefig("Storage_Temperature_Synergy.png", dpi=300, bbox_inches='tight')
    plt.show()
    print("✅ 高清协同调度图已生成！(已适配宋体五号字及Word真实尺寸)")


if __name__ == "__main__":
    plot_synergy_graph()