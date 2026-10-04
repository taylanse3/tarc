VERILATOR = verilator
TOP = tb_core

RTL = ../rtl/core/tarc_pkg.sv \
      ../rtl/core/alu.sv \
      ../rtl/core/regfile_int.sv \
      ../rtl/core/regfile_fp.sv \
      ../rtl/core/csr.sv \
      ../rtl/core/decode.sv \
      ../rtl/core/muldiv.sv \
      ../rtl/core/fpu_unpack.sv \
      ../rtl/core/fpu_round.sv \
      ../rtl/core/fpu_fma.sv \
      ../rtl/core/fpu_div.sv \
      ../rtl/core/fpu_sqrt.sv \
      ../rtl/core/fpu_f2i.sv \
      ../rtl/core/fpu_i2f.sv \
      ../rtl/core/fpu_misc.sv \
      ../rtl/core/fpu.sv \
      ../rtl/core/execute.sv \
      ../rtl/core/memory.sv \
      ../rtl/core/writeback.sv \
      ../rtl/core/hazard_unit.sv \
      ../rtl/core/fetch.sv \
      ../rtl/core/icache.sv \
      ../rtl/core/dcache.sv \
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
