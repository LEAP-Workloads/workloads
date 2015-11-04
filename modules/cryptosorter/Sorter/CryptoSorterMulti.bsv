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
`include "awb/provides/cryptosorter_common.bsh"
`include "awb/provides/cryptosorter_control.bsh"
`include "awb/provides/cryptosorter_sort_tree.bsh"
`include "awb/provides/cryptosorter_sorter.bsh"
`include "awb/provides/cryptosorter_memory_wrapper.bsh"
`include "awb/rrr/remote_server_stub_CRYPTOSORTERCONTROLRRR.bsh"


typedef enum {
  Init, 
  Idle,
  Waiting
} TopState deriving (Bits,Eq);

function Action recvDone(CONNECTION_RECV#(Bool) conn);
  action
    conn.deq();
  endaction
endfunction

function Action sendCommands(Instruction inst, CONNECTION_SEND#(Instruction) conn);
  action
    conn.send(inst);
  endaction
endfunction

function String getDoneString(Integer id);
  return "doneOut_" + integerToString(id);
endfunction

function String getCommandString(Integer id);
  return "commandIn_" + integerToString(id);
endfunction

module [CONNECTED_MODULE] mkConnectedApplication (Empty);

  ServerStub_CRYPTOSORTERCONTROLRRR serverStub <- mkServerStub_CRYPTOSORTERCONTROLRRR();
  Vector#(`SORTERS, Empty) sorters <- genWithM(mkSorter);
  Vector#(`SORTERS, CONNECTION_SEND#(Instruction)) commands <- mapM(mkConnectionSend, genWith(getCommandString));
  Vector#(`SORTERS, CONNECTION_RECV#(Bool)) dones <- mapM(mkConnectionRecv, genWith(getDoneString));

  Reg#(Bit#(40)) counter <- mkReg(0);
  Reg#(TopState) state <- mkReg(Idle);

  rule getfinished((state == Waiting));
    state <= Idle;
    joinActions(map(recvDone, dones));
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
    serverStub.sendResponse_PutInstruction(?);
    state <= Waiting;
  endrule


endmodule