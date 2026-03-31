import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
import matplotlib.cm as cm
import matplotlib.colors as mcolors

# =========================================================================
# 全局学术图表样式设置
# =========================================================================
plt.rcParams['font.sans-serif'] = ['SimSun', 'Times New Roman']
plt.rcParams['font.family'] = 'sans-serif'
plt.rcParams['axes.unicode_minus'] = False

# 保持 21 号大字体，以便插入 Word 缩小后变成完美的宋体五号字
plt.rcParams['font.size'] = 16
plt.rcParams['axes.titlesize'] = 18

file_path = 'Prediction_Error_3D.xlsx'


def plot_3d_scenarios():
    print("正在加载数据并绘制高精度 3D 图形...")
    df_wind = pd.read_excel(file_path, sheet_name='Wind_Error')
    df_pv = pd.read_excel(file_path, sheet_name='PV_Error')
    df_meta = pd.read_excel(file_path, sheet_name='MetaData')

    t = df_wind['Time'].values
    N_s = int(df_meta['Total_Scenarios'][0])
    worst_j = int(df_meta['Worst_Scenario_Index'][0])

    fig = plt.figure(figsize=(12, 8), dpi=300)

    # ==================== a. 风电预测误差三维分布 ====================
    ax1 = fig.add_subplot(121, projection='3d')
    cmap_wind = cm.get_cmap('viridis')
    norm_wind = mcolors.Normalize(vmin=1, vmax=N_s)

    for s in range(1, N_s + 1):
        col_name = f'S{s}'
        z_data = df_wind[col_name].values
        y_data = np.full_like(t, s)

        if s == worst_j:
            ax1.plot(t, y_data, z_data, color='#B22222', linewidth=2.5, marker='^', markersize=6, markerfacecolor='w',
                     zorder=10)
        else:
            ax1.plot(t, y_data, z_data, color=cmap_wind(norm_wind(s)), linewidth=1.0, alpha=0.8)

    ax1.view_init(elev=28, azim=-45)

    # 【修复 1】：去掉了 \n，让 Z 轴标签往回缩一点，不要撞到色带
    ax1.set_xlabel('\n时段 / h', labelpad=15)
    ax1.set_ylabel('\n场景编号', labelpad=15)
    ax1.set_zlabel('风电预测误差 / kW', labelpad=15)
    ax1.set_title('a. 风电预测误差三维分布', pad=15)

    # 风电 Colorbar
    sm1 = cm.ScalarMappable(cmap=cmap_wind, norm=norm_wind)
    sm1.set_array([])
    # 【修复 2】：pad 从 0.1 改为 0.18，把整个色带往右推
    cbar1 = fig.colorbar(sm1, ax=ax1, shrink=0.6, pad=0.18)
    # 【修复 3】：加上 labelpad=20，把“场景编号”四个字再往右推，彻底拉开空间
    cbar1.set_label('场景编号', labelpad=20)

    # ==================== b. 光伏预测误差三维分布 ====================
    ax2 = fig.add_subplot(122, projection='3d')
    cmap_pv = cm.get_cmap('afmhot_r')
    norm_pv = mcolors.Normalize(vmin=1, vmax=N_s)

    for s in range(1, N_s + 1):
        col_name = f'S{s}'
        z_data = df_pv[col_name].values
        y_data = np.full_like(t, s)

        if s == worst_j:
            ax2.plot(t, y_data, z_data, color='#0047AB', linewidth=2.5, marker='s', markersize=6, markerfacecolor='w',
                     zorder=10)
        else:
            ax2.plot(t, y_data, z_data, color=cmap_pv(norm_pv(s)), linewidth=1.0, alpha=0.8)

    ax2.view_init(elev=28, azim=-45)

    # 【同理修复】
    ax2.set_xlabel('\n时段 / h', labelpad=15)
    ax2.set_ylabel('\n场景编号', labelpad=15)
    ax2.set_zlabel('光伏预测误差 / kW', labelpad=15)
    ax2.set_title('b. 光伏预测误差三维分布', pad=15)

    # 光伏 Colorbar
    sm2 = cm.ScalarMappable(cmap=cmap_pv, norm=norm_pv)
    sm2.set_array([])
    # 【同理修复】
    cbar2 = fig.colorbar(sm2, ax=ax2, shrink=0.6, pad=0.18)
    cbar2.set_label('场景编号', labelpad=20)

    # 调整排版，防止边缘被裁掉
    plt.tight_layout(pad=2.0)
    plt.savefig('Figure_8_3D_Prediction_Error.png', dpi=300, bbox_inches='tight')
    plt.show()
    print("✅ Python 3D 图形绘制完成并保存为 600dpi 高清图像！")


if __name__ == '__main__':
    plot_3d_scenarios()