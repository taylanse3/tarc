VERILATOR = verilator
TOP = tb_core

RTL = ../rtl/core/tarc_pkg.sv \
      ../rtl/core/alu.sv \
      ../rtl/core/regfile_int.sv \
      ../rtl/core/csr.sv \
      ../rtl/core/decode.sv \
      ../rtl/core/execute.sv \
      ../rtl/core/memory.sv \
      ../rtl/core/writeback.sv \
      ../rtl/core/hazard_unit.sv \
      ../rtl/core/fetch.sv \
      ../rtl/core/core.sv

TB = ../tb/tb_core.sv

WAIVERS = -Wno-UNUSEDPARAM -Wno-IMPORTSTAR -Wno-UNUSEDSIGNAL -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC

.PHONY: all run lint clean

all: run

run:
	$(VERILATOR) --binary --timing $(WAIVERS) --top-module $(TOP) -o sim_tb $(RTL) $(TB)
	./obj_dir/sim_tb

lint:
	$(VERILATOR) --lint-only -Wall --timing --top-module core $(RTL)

clean:
	rm -rf obj_dir
