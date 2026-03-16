CC                  ?= clang
CFLAGS              ?= -Wall -Wextra -Werror -pedantic

GHDL                ?= ghdl
SURFER              ?= surfer
STD                 ?= 08
TOP                 ?= tb_fir
IVL                 ?= iverilog
VVP                 ?= vvp
VERIBLE             ?= verible-verilog-format
VERIBLE_SYNTAX      ?= verible-verilog-syntax
VERIBLE_LINT        ?= verible-verilog-lint
VERIBLE_LINT_FLAGS  ?= --rules=-module-filename,-parameter-name-style
VSG                 ?= vsg
VSG_FLAGS           ?= --fix

LATEX               ?= lualatex

FIR_DIR             := filter-design
FIR_SRC             := $(FIR_DIR)/fir_filter.c
FIR_BIN             := $(FIR_DIR)/fir_filter
DATA_DIR            := $(abspath $(FIR_DIR))
IN_DIR              := $(DATA_DIR)/inputs

GEN_DIR             := $(abspath generated)
GEN_C_DIR           := $(GEN_DIR)/c
GEN_RTL_DIR         := $(GEN_DIR)/rtl

IN_REF              := $(IN_DIR)/input_reference_ecg.txt
IN_HV               := $(IN_DIR)/input_high_variability_ecg.txt
IN_BS               := $(IN_DIR)/input_baseline_shifted_ecg.txt

OUT_C_REF           := $(GEN_C_DIR)/output_reference_ecg.txt
OUT_C_HV            := $(GEN_C_DIR)/output_high_variability_ecg.txt
OUT_C_BS            := $(GEN_C_DIR)/output_baseline_shifted_ecg.txt

OUT_RTL_REF         := $(GEN_RTL_DIR)/output_reference_ecg_vhdl_sim.txt
OUT_RTL_HV          := $(GEN_RTL_DIR)/output_high_variability_ecg_vhdl_sim.txt
OUT_RTL_BS          := $(GEN_RTL_DIR)/output_baseline_shifted_ecg_vhdl_sim.txt

OUT_RTL_REF_V := $(GEN_RTL_DIR)/output_reference_ecg_verilog_sim.txt
OUT_RTL_HV_V  := $(GEN_RTL_DIR)/output_high_variability_ecg_verilog_sim.txt
OUT_RTL_BS_V  := $(GEN_RTL_DIR)/output_baseline_shifted_ecg_verilog_sim.txt

VHDL_GENERIC_ARGS := \
	-ginput_ref_path=$(IN_REF) \
	-ginput_hv_path=$(IN_HV) \
	-ginput_bs_path=$(IN_BS) \
	-gexpected_ref_path=$(OUT_C_REF) \
	-gexpected_hv_path=$(OUT_C_HV) \
	-gexpected_bs_path=$(OUT_C_BS) \
	-goutput_ref_path=$(OUT_RTL_REF) \
	-goutput_hv_path=$(OUT_RTL_HV) \
	-goutput_bs_path=$(OUT_RTL_BS)

VERILOG_PLUSARGS := \
	+INPUT_REF_PATH=$(IN_REF) \
	+INPUT_HV_PATH=$(IN_HV) \
	+INPUT_BS_PATH=$(IN_BS) \
	+EXPECTED_REF_PATH=$(OUT_C_REF) \
	+EXPECTED_HV_PATH=$(OUT_C_HV) \
	+EXPECTED_BS_PATH=$(OUT_C_BS) \
	+OUTPUT_REF_PATH=$(OUT_RTL_REF_V) \
	+OUTPUT_HV_PATH=$(OUT_RTL_HV_V) \
	+OUTPUT_BS_PATH=$(OUT_RTL_BS_V)

VHDL_DIR            := rtl/vhdl
VHDL_WAVE           := fir.vcd
VHDL_SRC            := fir_filter.vhdl testbench.vhdl

VERILOG_DIR         := rtl/verilog
VERILOG_BIN         := tb_fir.out
VERILOG_WAVE        := fir.vcd
VERILOG_SRC         := fir_filter.v testbench.v

PAPER_DIR           := docs
PAPER_NAME          := paper


.PHONY: all rtl-run vhdl verilog fir fir-run vhdl-run vhdl-surfer verilog-run verilog-surfer format format-verilog format-vhdl paper clean clean-pdf clean-imgs

all: rtl-run

rtl-run: vhdl verilog

vhdl: vhdl-run

verilog: verilog-run

fir: $(FIR_BIN)

$(FIR_BIN): $(FIR_SRC)
	$(CC) $(CFLAGS) $(FIR_SRC) -o $(FIR_BIN)

fir-run: fir
	mkdir -p $(GEN_C_DIR)
	cd $(FIR_DIR) && ./fir_filter

vhdl-run: fir-run
	mkdir -p $(GEN_RTL_DIR)
	cd $(VHDL_DIR) && $(GHDL) -a --std=$(STD) $(VHDL_SRC)
	cd $(VHDL_DIR) && $(GHDL) -e --std=$(STD) $(TOP)
	cd $(VHDL_DIR) && $(GHDL) -r --std=$(STD) $(TOP) --vcd=$(VHDL_WAVE) $(VHDL_GENERIC_ARGS)

vhdl-surfer: vhdl-run
	cd $(VHDL_DIR) && $(SURFER) $(VHDL_WAVE)

verilog-run: fir-run
	mkdir -p $(GEN_RTL_DIR)
	cd $(VERILOG_DIR) && $(IVL) -g2012 -o $(VERILOG_BIN) $(VERILOG_SRC)
	cd $(VERILOG_DIR) && $(VVP) $(VERILOG_BIN) $(VERILOG_PLUSARGS)

verilog-surfer: verilog-run
	cd $(VERILOG_DIR) && $(SURFER) $(VERILOG_WAVE)

format: format-verilog format-vhdl

format-verilog: SRC := $(addprefix $(VERILOG_DIR)/,$(VERILOG_SRC))
format-verilog:
	@if ! command -v $(VERIBLE) >/dev/null 2>&1; then \
		echo "Error: $(VERIBLE) not found. Install verible."; \
		exit 1; \
	fi
	$(VERIBLE) --inplace $(SRC)
	$(VERIBLE_SYNTAX) $(SRC)
	$(VERIBLE_LINT) $(VERIBLE_LINT_FLAGS) $(SRC)

format-vhdl: SRC := $(addprefix $(VHDL_DIR)/,$(VHDL_SRC))
format-vhdl:
	@if ! command -v $(VSG) >/dev/null 2>&1; then \
		echo "Error: $(VSG) not found. Install vhdl-style-guide (vsg)."; \
		exit 1; \
	fi
	@$(VSG) $(VSG_FLAGS) $(SRC) || \
		echo "Warning: vsg reported remaining style violations that could not be auto-fixed."

paper:
	cd $(PAPER_DIR) && $(LATEX) -jobname=$(PAPER_NAME) main.tex
	cd $(PAPER_DIR) && $(LATEX) -jobname=$(PAPER_NAME) main.tex

clean:
	rm -f $(FIR_BIN)
	cd $(VHDL_DIR) && rm -f *.cf $(VHDL_WAVE) *.o $(TOP)
	cd $(VERILOG_DIR) && rm -f $(VERILOG_BIN) $(VERILOG_WAVE)
	rm -rf $(GEN_DIR)
	cd $(PAPER_DIR) && rm -f *.aux *.log *.out *.fls *.fdb_latexmk *.toc

clean-pdf:
	rm -f $(PAPER_DIR)/$(PAPER_NAME).pdf
