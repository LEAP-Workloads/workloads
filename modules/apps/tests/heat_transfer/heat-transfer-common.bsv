`include "awb/provides/heat_transfer_common.bsh"
typedef Bit#(64) CYCLE_COUNTER;

typedef `HEAT_TRANSFER_X_MAX_POINTS N_X_MAX_POINTS;
typedef `HEAT_TRANSFER_Y_MAX_POINTS N_Y_MAX_POINTS;
typedef `HEAT_TRANSFER_X_ENGINE N_X_ENGINES;
typedef `HEAT_TRANSFER_Y_ENGINE N_Y_ENGINES;
typedef TMul#(N_X_ENGINES, N_Y_ENGINES) N_TOTAL_ENGINES;

`ifndef HEAT_TRANSFER_DUAL_FPGA_ENABLE_Z
    typedef TDiv#(N_TOTAL_ENGINES,2) N_LOCAL_ENGINES;
`else
    typedef N_TOTAL_ENGINES N_LOCAL_ENGINES;
`endif

typedef TSub#(N_TOTAL_ENGINES, N_LOCAL_ENGINES) N_REMOTE_ENGINES;
typedef TMul#(N_X_MAX_POINTS, N_Y_MAX_POINTS)  N_TOTAL_MAX_POINTS;
typedef Bit#(TAdd#(TAdd#(TLog#(N_X_MAX_POINTS),TLog#(N_Y_MAX_POINTS)),2)) MEM_ADDRESS;
typedef Bit#(8) TEST_DATA;

