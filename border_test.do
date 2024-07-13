vlog VGA_interface.v

vsim -L altera_mf_ver border_anim
#module border_anim
#(
#parameter 	X_SIZE = 320,
#			Y_SIZE = 30,
#			TRANSPARENT = 3'b000
#)
#(
#	input clk,
#	input resetn,
#	input enable,
#	input [($clog2(X_SIZE)):0] orig_x,
#	input [($clog2(Y_SIZE)):0] orig_y,
#	output reg [($clog2(X_SIZE)):0] pt_x,
#	output reg [($clog2(Y_SIZE)):0] pt_y,
#	output [2:0] colour,
#	output reg plot,
#	output reg done
#);

log {/*}
add wave -unsigned {/*}
add wave -unsigned -color cyan {/borderMemory/*}
force {clk} 1 0, 0 {5ps} -r 10ps
force {resetn} 0
force {enable} 1
force {x_orig} 0
force {y_orig} 0
run 20ps

force {resetn} 1
run 1000ps
