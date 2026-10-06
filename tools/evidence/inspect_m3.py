import pya
import sys

gds_path = '/mnt/d/domixi/output/physical/sky130_dma_bus_firewall/dma_bus_firewall.gds'
layout = pya.Layout()
layout.read(gds_path)
top = layout.top_cell()
dbu = layout.dbu
print(f'DBU = {dbu}')
layer_info = pya.LayerInfo(70, 20)
m3_layer = layout.layer(layer_info)

reg = pya.Region(top.begin_shapes_rec(m3_layer))
reg.merge()

min_area_dbu2 = int(round(0.240 / (dbu * dbu)))
bad_reg = reg.with_area(0, min_area_dbu2)
print(f'Found {bad_reg.count()} bad polygons with area < 0.240 um2')

areas = [p.area() * dbu * dbu for p in bad_reg.each()]
if areas:
    print(f'Min area = {min(areas):.4f} um2, Max area = {max(areas):.4f} um2, Mean = {sum(areas)/len(areas):.4f} um2')

pya.Application.instance().exit(0)
