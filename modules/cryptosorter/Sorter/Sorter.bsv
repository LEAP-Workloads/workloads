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

/* This is the top-level sorter module.  It interfaces to the PLB bus, the 
   DSOCM, and the sorter core. Not much functionality, but it does have 
   a cycle timer, and sends periodic messages back to the PPC over the 
   DSOCM 
*/ 

import FIFO::*;
import GetPut::*;

// Local Imports
`include "asim/provides/librl_bsv.bsh"
`include "awb/provides/soft_connections.bsh"
`include "awb/provides/soft_services.bsh"
`include "awb/provides/soft_services_lib.bsh"
`include "awb/provides/soft_services_deps.bsh"
`include "awb/provides/cryptosorter_common.bsh"
`include "awb/provides/cryptosorter_control.bsh"
`include "awb/provides/cryptosorter_sort_tree.bsh"
`include "awb/provides/cryptosorter_memory_wrapper.bsh"
`include "awb/rrr/remote_server_stub_CRYPTOSORTERCONTROLRRR.bsh"


typedef enum {
// Initializing, We need to add some initialization at some point so as to test different operating points...
  Idle,
  Waiting
} TopState deriving (Bits,Eq);

module [CONNECTED_MODULE] mkConnectedApplication (Empty);

  ServerStub_CRYPTOSORTERCONTROLRRR serverStub <- mkServerStub_CRYPTOSORTERCONTROLRRR();
  ExternalMemory extMem <- mkExternalMemory();
  Control  controller <- mkControl(extMem);
    
  Reg#(Bit#(5)) size <- mkReg(0);
  Reg#(Bit#(3)) passes <- mkReg(1);
  Reg#(TopState) state <- mkReg(Idle);
  Reg#(Bit#(40)) counter <- mkReg(0);

  rule getfinished((state == Waiting) && controller.finished);
    state <= Idle;
  endrule

  rule countUp(state != Idle);
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

  rule sendCommand(controller.finished && (state == Idle));    
    let inst <- serverStub.acceptRequest_PutInstruction();       
    serverStub.sendResponse_PutInstruction(?);
    controller.doSort(truncate(pack(inst)));
    size <= truncate(pack(inst));
    state <= Waiting;
    counter <= 0;
    passes <= 1;
  endrule

  rule returnPass;
    let msg <- controller.msgs.get;
    passes <= passes + 1;
  endrule  

endmodule