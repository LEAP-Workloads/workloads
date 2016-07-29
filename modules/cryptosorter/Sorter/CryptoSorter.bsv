/*
Copyright (c) 2008 MIT

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

Author: Kermin Fleming
*/

import FIFO::*;
import GetPut::*;
import LFSR::*;
import Vector::*;

// Local Imports
`include "asim/provides/librl_bsv.bsh"
`include "awb/provides/soft_connections.bsh"
`include "awb/provides/soft_services.bsh"
`include "awb/provides/soft_services_lib.bsh"
`include "awb/provides/soft_services_deps.bsh"
`include "awb/provides/common_services.bsh"
`include "awb/provides/cryptosorter_common.bsh"
`include "awb/provides/cryptosorter_control.bsh"
`include "awb/provides/cryptosorter_sort_tree.bsh"
`include "awb/provides/cryptosorter_sorter.bsh"
`include "awb/provides/cryptosorter_memory_wrapper.bsh"
`include "awb/rrr/remote_server_stub_CRYPTOSORTERCONTROLRRR.bsh"
`include "awb/dict/PARAMS_CRYPTOSORTER_SORTER.bsh" 

typedef 40 CYCLE_COUNTER_SZ;

typedef enum {
  Idle,
  Init, 
  Waiting,
  DumpCycle
} TopState deriving (Bits,Eq);

function Action recvDone(CONNECTION_RECV#(Bit#(CYCLE_COUNTER_SZ)) conn);
  action
    conn.deq();
  endaction
endfunction

function Action sendCommands(Instruction inst, CONNECTION_SEND#(Instruction) conn);
  action
    conn.send(inst);
  endaction
endfunction

function Action sendStart(CONNECTION_SEND#(Bool) conn);
  action
    conn.send(True);
  endaction
endfunction

function Bit#(CYCLE_COUNTER_SZ) getDoneCycle(CONNECTION_RECV#(Bit#(CYCLE_COUNTER_SZ)) conn);
  return conn.receive();
endfunction

function String getDoneString(Integer id);
  return "sorter_doneOut_" + integerToString(id);
endfunction

function String getCommandString(Integer id);
  return "sorter_commandIn_" + integerToString(id);
endfunction

function String getStartString(Integer id);
  return "sorter_startIn_" + integerToString(id);
endfunction

`ifdef TOP_LEVEL_SORTERS
    `define SORTERS `TOP_LEVEL_SORTERS
`endif

module [CONNECTED_MODULE] mkConnectedApplication (Empty);

  ServerStub_CRYPTOSORTERCONTROLRRR serverStub <- mkServerStub_CRYPTOSORTERCONTROLRRR();

`ifdef TOP_LEVEL_SORTERS
  Vector#(`SORTERS, Empty) sorters <- genWithM(mkSorter);
`endif

  Vector#(`SORTERS, CONNECTION_SEND#(Instruction)) commands <- mapM(mkConnectionSend, genWith(getCommandString));
  Vector#(`SORTERS, CONNECTION_SEND#(Bool)) starts <- mapM(mkConnectionSend, genWith(getStartString));
  Vector#(`SORTERS, CONNECTION_RECV#(Bit#(CYCLE_COUNTER_SZ))) dones <- mapM(mkConnectionRecv, genWith(getDoneString));

  Reg#(Bit#(CYCLE_COUNTER_SZ)) counter <- mkReg(0);
  Reg#(TopState) state <- mkReg(Idle);
  Reg#(Bit#(2)) instStyle <- mkReg(0);  
  Reg#(Bit#(5)) instSize <- mkReg(0);
  Reg#(Vector#(`SORTERS, Bit#(CYCLE_COUNTER_SZ))) doneCycles <- mkReg(unpack(0));


  // Dump execution cycles for each sorter

  PARAMETER_NODE paramNode     <- mkDynamicParameterNode();
  Param#(1) param_dump_cycle  <- mkDynamicParameter(`PARAMS_CRYPTOSORTER_SORTER_SORTER_INDIVIDUAL_CYCLE_EN, paramNode);
  let dumpCycle = (param_dump_cycle == 1);
    
  STDIO#(Bit#(64))  stdio <- mkStdIO();
  let doneMsg  <- getGlobalStringUID("%d:%d:%llu\n");
  Reg#(Bit#(TLog#(`SORTERS))) sorterCnt <- mkReg(0);

  rule dumpDoneCycle(state == DumpCycle);
    stdio.printf(doneMsg, list3(1<<instSize,
                                zeroExtend(instStyle),
                                zeroExtend(doneCycles[sorterCnt])));
    if (sorterCnt == fromInteger(`SORTERS -1))
    begin
        sorterCnt <= 0;
        state <= Idle;
    end
    else
    begin
        sorterCnt <= sorterCnt + 1;
    end 
  endrule

  rule getfinished((state == Waiting));
    let cycles = map(getDoneCycle, dones);
    doneCycles <= cycles;
    joinActions(map(recvDone, dones));
    if (dumpCycle)
    begin
        state <= DumpCycle;
    end
    else
    begin
        state <= Idle;
    end
  endrule

  rule countUp(state == Waiting);
    counter <= counter + 1;
  endrule

  rule dropCountReq(state != Idle);
     let inst <- serverStub.acceptRequest_ReadCycleCount();       
     serverStub.sendResponse_ReadCycleCount(0,?);
  endrule

  rule readCount(state == Idle);
     let inst <- serverStub.acceptRequest_ReadCycleCount();       
     serverStub.sendResponse_ReadCycleCount(1,zeroExtend(counter));
  endrule

  rule sendCommand(state == Idle);    
    let inst <- serverStub.acceptRequest_PutInstruction();
    joinActions(map(sendCommands(Instruction{size: inst.size, style: inst.style, seed: inst.seed}),commands));       
    instSize  <= truncate(pack(inst.size));
    instStyle <= truncate(pack(inst.style));
    serverStub.sendResponse_PutInstruction(?);
    state   <= Init;
  endrule

  rule waitForInitDone(state == Init);
    state <= Waiting;
    counter <= 0;
    joinActions(map(recvDone, dones));
    joinActions(map(sendStart,starts));       
  endrule

endmodule

