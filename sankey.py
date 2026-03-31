import plotly.graph_objects as go

# ==========================================
# 1. 你的真实数据填充区 (已清理掉多余的测试数据)
# ==========================================
E_Grid = 57947.44
E_Wind = 112734.00
E_PV = 83472.00
E_ESS_dis = 7920.00
E_HFC_e = 2821.66
E_Load = 92242.65
E_DC = 26432.75
E_EB = 115988.50
E_EC = 4786.75
E_EL = 15666.67
E_ESS_ch = 9777.78
H2_from_EL = 9400.00
H2_to_HFC = 7614.00
H_EB = 110189.08
H_HFC = 4030.94
H_Load = 114220.02
H_to_AC = 0.00
DC_Waste = 15595.32
DC_Compute = 10837.43
DC_Waste_to_AC = 10283.27
DC_Unrecovered = 5312.06
C_EC_bus = 18620.46
C_EC_DC = 0.00
C_AC_bus = 8121.07
C_AC_DC = 105.54
C_Load = 26741.53

# (自动计算隐藏的物理平衡量)
# 电制冷机 COP > 1，多出来的能量来自环境空气热能
Ambient_Heat_to_EC = (C_EC_bus + C_EC_DC) - E_EC

# ==========================================
# 2. 定义节点 (Nodes)
# ==========================================
labels = [
    "主网购电", "风电出力", "光伏出力", "电储能放电", "电母线 (电力枢纽)", # 0-4
    "常规电负荷", "数据中心 IT", "电储能充电", "电解槽 (EL)", "电锅炉 (EB)", "电制冷机 (EC)", # 5-10
    "算力产出", "数据中心余热", # 11-12
    "储氢系统", "氢燃料电池 (HFC)", # 13-14
    "热母线 (热力枢纽)", "常规热负荷", "吸收式制冷 (AC)", # 15-17
    "环境空气 (制冷COP源)", "冷母线 (冷力枢纽)", "常规冷负荷", # 18-20
    "机房环境热交换 (温控微循环)", "系统能量损耗" # 21-22
]

# 节点颜色 (SCI 高级学术色系)
node_colors = [
    "#E63946", "#219EBC", "#FFB703", "#8CB369", "#FFD166",
    "#457B9D", "#9B5DE5", "#8CB369", "#F4A261", "#BC6C25", "#A8DADC",
    "#6A4C93", "#E07A5F",
    "#8ECAE6", "#1D3557",
    "#F25C54", "#F25C54", "#F4A261",
    "#E5E5E5", "#A8DADC", "#A8DADC",
    "#3D5A80", "#D3D3D3"
]

# ==========================================
# 3. 定义流向连线 (Source -> Target)
# ==========================================
source = []; target = []; value = []; link_colors = []

def add_link(src, tgt, val, color="rgba(169, 169, 169, 0.4)"):
    if val > 0:
        source.append(src); target.append(tgt); value.append(val); link_colors.append(color)

# -- 源 -> 电母线 --
c_e = "rgba(255, 209, 102, 0.5)"
add_link(0, 4, E_Grid, c_e); add_link(1, 4, E_Wind, c_e)
add_link(2, 4, E_PV, c_e); add_link(3, 4, E_ESS_dis, c_e)
add_link(14, 4, E_HFC_e, c_e)

# -- 电母线 -> 设备/负荷 --
add_link(4, 5, E_Load, c_e); add_link(4, 6, E_DC, c_e)
add_link(4, 7, E_ESS_ch, c_e); add_link(4, 8, E_EL, c_e)
add_link(4, 9, E_EB, c_e); add_link(4, 10, E_EC, c_e)

# -- 数据中心内部流向 --
c_dc = "rgba(155, 93, 229, 0.4)"
add_link(6, 11, DC_Compute, c_dc)
add_link(6, 12, DC_Waste, "rgba(224, 122, 95, 0.5)")
add_link(12, 17, DC_Waste_to_AC, "rgba(224, 122, 95, 0.5)")
add_link(12, 21, DC_Unrecovered, "rgba(224, 122, 95, 0.3)")

# -- 氢能流向 --
c_h2 = "rgba(142, 202, 230, 0.6)"
add_link(8, 13, H2_from_EL, c_h2); add_link(8, 22, E_EL - H2_from_EL, "rgba(211,211,211,0.5)")
add_link(13, 14, H2_to_HFC, c_h2)
add_link(14, 15, H_HFC, "rgba(242, 92, 84, 0.5)")
add_link(14, 22, H2_to_HFC - E_HFC_e - H_HFC, "rgba(211,211,211,0.5)")

# -- 热能流向 --
c_h = "rgba(242, 92, 84, 0.5)"
add_link(9, 15, H_EB, c_h); add_link(9, 22, E_EB - H_EB, "rgba(211,211,211,0.5)")
add_link(15, 16, H_Load, c_h); add_link(15, 17, H_to_AC, c_h)

# -- 冷能与制冷机流向 --
c_c = "rgba(168, 218, 220, 0.6)"
add_link(18, 10, Ambient_Heat_to_EC, "rgba(229, 229, 229, 0.5)")
add_link(10, 19, C_EC_bus, c_c); add_link(10, 21, C_EC_DC, c_c)
add_link(17, 19, C_AC_bus, c_c); add_link(17, 21, C_AC_DC, c_c)
add_link(17, 22, (H_to_AC + DC_Waste_to_AC) - (C_AC_bus + C_AC_DC), "rgba(211,211,211,0.5)")
add_link(19, 20, C_Load, c_c)

# ==========================================
# 4. 渲染图表
# ==========================================
fig = go.Figure(data=[go.Sankey(
    arrangement = "snap",
    node = dict(
      pad = 20, thickness = 25,
      line = dict(color = "white", width = 1),
      label = labels, color = node_colors
    ),
    link = dict(source = source, target = target, value = value, color = link_colors)
)])

fig.update_layout(
    # title_text="全景多能流时空耦合与转换桑基图（电-热-冷-氢-算）",
    font_size=20, font_family="SimSun",
    width=1300, height=800,
    margin=dict(t=60, b=40, l=40, r=40)
)

print("正在生成高清图片，请稍候...")

# 显示交互图
fig.show()

# 直接导出 3 倍缩放的高清 PNG (足够应对 SCI 盲审)
try:
    fig.write_image("Full_System_Sankey.png", scale=3)
    print("✅ 全系统桑基图绘制完成！已保存为 Full_System_Sankey.png")
except Exception as e:
    print(f"⚠️ 图片导出失败，原因是: {e}")
    print("请确保已按导师指示更新了 kaleido 库！")