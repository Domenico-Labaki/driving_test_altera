# driving_test.sdc — Timing Constraints for GEL372 Driving Test
# Target: EP2C35F672C6 (Cyclone II)

# ── Primary clock ────────────────────────────────────────────────────────────
create_clock -name {CLOCK_50} -period 20.000 -waveform {0.000 10.000} [get_ports {CLOCK_50}]

# ── Generated clock (pixel clock: CLOCK_50 / 2) ───────────────────────────────
create_generated_clock -name {pclk} \
    -source [get_ports {CLOCK_50}] \
    -divide_by 2 \
    [get_registers {u_vga|clk25}]

# ── Input delay assumptions (switches/keys through PCB) ──────────────────────
set_input_delay -clock {CLOCK_50} -max 5.0 [get_ports {KEY[*]}]
set_input_delay -clock {CLOCK_50} -min 1.0 [get_ports {KEY[*]}]
set_input_delay -clock {CLOCK_50} -max 5.0 [get_ports {SW[*]}]
set_input_delay -clock {CLOCK_50} -min 1.0 [get_ports {SW[*]}]

# ── Output delay assumptions (VGA, LEDs, LCD, 7-seg) ─────────────────────────
set_output_delay -clock {CLOCK_50} -max 2.0 [get_ports {VGA_*}]
set_output_delay -clock {CLOCK_50} -min 0.0 [get_ports {VGA_*}]
set_output_delay -clock {CLOCK_50} -max 2.0 [get_ports {LEDR[*]}]
set_output_delay -clock {CLOCK_50} -max 2.0 [get_ports {LEDG[*]}]
set_output_delay -clock {CLOCK_50} -max 2.0 [get_ports {HEX*}]
set_output_delay -clock {CLOCK_50} -max 2.0 [get_ports {LCD_*}]

# ── False paths for asynchronous control signals ──────────────────────────────
set_false_path -from [get_ports {KEY[*]}] -to *
set_false_path -from [get_ports {SW[*]}]  -to *
