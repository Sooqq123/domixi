import os
import subprocess
import sys

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
OUTPUT_DIR = os.path.join(REPO_ROOT, 'output', 'sim_regression')
os.makedirs(OUTPUT_DIR, exist_ok=True)

RTL_DIR = os.path.join(REPO_ROOT, 'rtl')
TB_DIR = os.path.join(REPO_ROOT, 'tb')
DMA_RTL = os.path.join(REPO_ROOT, 'DMA-controller', 'rtl')
PICO_RTL = os.path.join(REPO_ROOT, 'picorv32-main', 'picorv32-main', 'picorv32.v')

FIREWALL_RTL = [
    os.path.join(RTL_DIR, 'fw_axi_address_slice.v'),
    os.path.join(RTL_DIR, 'fw_context_tracker.v'),
    os.path.join(RTL_DIR, 'fw_apb_regs.v'),
    os.path.join(RTL_DIR, 'fw_acl_matcher.v'),
    os.path.join(RTL_DIR, 'fw_drain_fsm.v'),
    os.path.join(RTL_DIR, 'fw_write_drain.v'),
    os.path.join(RTL_DIR, 'fw_read_drain.v'),
    os.path.join(RTL_DIR, 'fw_data_path_mux.v'),
    os.path.join(RTL_DIR, 'fw_hdc_sense.v'),
    os.path.join(RTL_DIR, 'fw_honeypot_sink.v'),
    os.path.join(RTL_DIR, 'fw_mtd_engine.v'),
    os.path.join(RTL_DIR, 'fw_closed_loop_ctrl.v'),
    os.path.join(RTL_DIR, 'dma_bus_firewall.v')
]

DMA_FILES = [
    os.path.join(DMA_RTL, 'dma_apb_slave.v'),
    os.path.join(DMA_RTL, 'dma_axi_master.v'),
    os.path.join(DMA_RTL, 'dma_fifo_latch.v'),
    os.path.join(DMA_RTL, 'dma_controller.v')
]

TESTS = [
    {
        'name': 'tb_adversarial_m1',
        'sources': [os.path.join(RTL_DIR, 'fw_hdc_sense.v'), os.path.join(TB_DIR, 'tb_adversarial_m1.v')],
        'pass_str': '=== ADVERSARIAL STRESS TESTS COMPLETE ==='
    },
    {
        'name': 'tb_aegis_picorv32_soc',
        'sources': [PICO_RTL] + DMA_FILES + FIREWALL_RTL + [os.path.join(RTL_DIR, 'aegis_picorv32_apb_bridge.v'), os.path.join(RTL_DIR, 'aegis_soc_top.v'), os.path.join(TB_DIR, 'tb_aegis_picorv32_soc.v')],
        'pass_str': '[PASS] tb_aegis_picorv32_soc'
    },
    {
        'name': 'tb_aegis_soc_reset',
        'sources': [PICO_RTL] + DMA_FILES + FIREWALL_RTL + [os.path.join(RTL_DIR, 'aegis_picorv32_apb_bridge.v'), os.path.join(RTL_DIR, 'aegis_soc_top.v'), os.path.join(TB_DIR, 'tb_aegis_soc_reset.v')],
        'pass_str': '[PASS] tb_aegis_soc_reset reset contract'
    },
    {
        'name': 'tb_aegis_soc',
        'sources': FIREWALL_RTL + [os.path.join(TB_DIR, 'tb_aegis_soc.v')],
        'pass_str': 'AEGIS-RISC VERIFICATION SUMMARY: 16 PASSED, 0 FAILED'
    },
    {
        'name': 'tb_dma_bus_firewall',
        'sources': FIREWALL_RTL + [os.path.join(TB_DIR, 'tb_dma_bus_firewall.v')],
        'pass_str': 'ALL TESTS PASSED SUCCESSFULLY! (0 failures)'
    },
    {
        'name': 'tb_fw_acl_matcher',
        'sources': [os.path.join(RTL_DIR, 'fw_acl_matcher.v'), os.path.join(TB_DIR, 'tb_fw_acl_matcher.v')],
        'pass_str': 'PASS: tb_fw_acl_matcher'
    },
    {
        'name': 'tb_fw_apb_regs',
        'sources': [os.path.join(RTL_DIR, 'fw_apb_regs.v'), os.path.join(TB_DIR, 'tb_fw_apb_regs.v')],
        'pass_str': 'PASS: tb_fw_apb_regs'
    },
    {
        'name': 'tb_fw_axi_address_slice',
        'sources': [os.path.join(RTL_DIR, 'fw_axi_address_slice.v'), os.path.join(TB_DIR, 'tb_fw_axi_address_slice.v')],
        'pass_str': 'PASS: tb_fw_axi_address_slice'
    },
    {
        'name': 'tb_fw_closed_loop_ctrl',
        'sources': [os.path.join(RTL_DIR, 'fw_closed_loop_ctrl.v'), os.path.join(TB_DIR, 'tb_fw_closed_loop_ctrl.v')],
        'pass_str': '[ALL TESTS PASSED] fw_closed_loop_ctrl verified successfully!'
    },
    {
        'name': 'tb_fw_context_tracker',
        'sources': [os.path.join(RTL_DIR, 'fw_context_tracker.v'), os.path.join(TB_DIR, 'tb_fw_context_tracker.v')],
        'pass_str': 'PASS: tb_fw_context_tracker'
    },
    {
        'name': 'tb_fw_data_path_mux',
        'sources': [os.path.join(RTL_DIR, 'fw_data_path_mux.v'), os.path.join(TB_DIR, 'tb_fw_data_path_mux.v')],
        'pass_str': 'PASS: tb_fw_data_path_mux'
    },
    {
        'name': 'tb_fw_drain_fsm',
        'sources': [os.path.join(RTL_DIR, 'fw_write_drain.v'), os.path.join(RTL_DIR, 'fw_read_drain.v'), os.path.join(RTL_DIR, 'fw_drain_fsm.v'), os.path.join(TB_DIR, 'tb_fw_drain_fsm.v')],
        'pass_str': 'PASS: tb_fw_drain_fsm'
    },
    {
        'name': 'tb_fw_hdc_sense',
        'sources': [os.path.join(RTL_DIR, 'fw_hdc_sense.v'), os.path.join(TB_DIR, 'tb_fw_hdc_sense.v')],
        'pass_str': '[PASS] tb_fw_hdc_sense completed with zero check failures!'
    },
    {
        'name': 'tb_fw_hdc_sense_challenger2',
        'sources': [os.path.join(RTL_DIR, 'fw_hdc_sense.v'), os.path.join(TB_DIR, 'tb_fw_hdc_sense_challenger2.v')],
        'pass_str': 'CHALLENGER 2 VERDICT: [PASS]'
    },
    {
        'name': 'tb_fw_honeypot_sink',
        'sources': [os.path.join(RTL_DIR, 'fw_honeypot_sink.v'), os.path.join(TB_DIR, 'tb_fw_honeypot_sink.v')],
        'pass_str': '[ALL TESTS PASSED] fw_honeypot_sink verified successfully!'
    },
    {
        'name': 'tb_fw_read_drain',
        'sources': [os.path.join(RTL_DIR, 'fw_read_drain.v'), os.path.join(TB_DIR, 'tb_fw_read_drain.v')],
        'pass_str': 'PASS: tb_fw_read_drain'
    },
    {
        'name': 'tb_fw_write_drain',
        'sources': [os.path.join(RTL_DIR, 'fw_write_drain.v'), os.path.join(TB_DIR, 'tb_fw_write_drain.v')],
        'pass_str': 'PASS: tb_fw_write_drain'
    },
    {
        'name': 'tb_fw_abnormal_stress',
        'sources': FIREWALL_RTL + [os.path.join(TB_DIR, 'tb_fw_abnormal_stress.v')],
        'pass_str': '=== ABNORMAL STRESS REGRESSION COMPLETE: 0 FAILURES ==='
    },
    {
        'name': 'tb_soc_dma_firewall_contract',
        'sources': DMA_FILES + FIREWALL_RTL + [os.path.join(TB_DIR, 'tb_soc_dma_firewall_contract.v')],
        'pass_str': 'PASS: tb_soc_dma_firewall_contract (PRODUCTION FIREWALL IP)'
    }
]

inc_args = ['-I' + RTL_DIR, '-I' + os.path.join(RTL_DIR, 'generated'), '-I' + TB_DIR]
passed = 0
failed = 0

for t in TESTS:
    name = t['name']
    vvp_file = os.path.join(OUTPUT_DIR, name + '.vvp')
    log_file = os.path.join(OUTPUT_DIR, name + '.log')
    cmd = ['iverilog', '-g2012'] + inc_args + ['-o', vvp_file] + t['sources']
    comp = subprocess.run(cmd, capture_output=True, text=True)
    if comp.returncode != 0:
        print(f'[-] COMPILE FAIL: {name}')
        print(comp.stderr[:300])
        failed += 1
        continue
    sim = subprocess.run(['vvp', vvp_file], capture_output=True, text=True, timeout=120)
    with open(log_file, 'w', encoding='utf-8') as f:
        f.write(sim.stdout)
    if t['pass_str'] in sim.stdout and sim.returncode == 0:
        print(f'[+] PASS: {name}')
        passed += 1
    else:
        print(f'[-] SIM FAIL: {name}')
        print(sim.stdout[-300:])
        failed += 1

print('=' * 60)
print(f'FINAL SIMULATION RESULTS: {passed}/{len(TESTS)} PASSED, {failed} FAILED')
print('=' * 60)
