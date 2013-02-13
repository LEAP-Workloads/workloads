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

/*  This module serves as an abstraction layer for wrapping an external memory
    system.  In particular, it emulates a parametric number  of
    read and write virtual channels, sheilding the user module from the actual 
    details of the underlying memory system.  Thus, user modules may be 
    implemented targeting the same "External Memory" and then used in 
    systems with radically different memory subsystems. The module orders writes
    before reads. It is additionally parameterized by address width (Addr) 
    and data width.
*/ 


import Vector::*;
import FIFOF::*;
import GetPut::*;


`include "awb/provides/cryptosorter_common.bsh"

`include "awb/provides/librl_bsv.bsh"
`include "awb/provides/soft_connections.bsh"
`include "awb/provides/soft_services.bsh"
`include "awb/provides/soft_services_lib.bsh"
`include "awb/provides/soft_services_deps.bsh"
`include "awb/provides/mem_services.bsh"
`include "awb/provides/common_services.bsh"
`include "awb/dict/VDEV_SCRATCH.bsh"

module [CONNECTED_MODULE] mkExternalMemory (ExternalMemory);

    let recordsPerMemRequest = fromInteger(valueof(RecordsPerMemRequest));

    // we might want to partition this into two address spaces at some point ...
    MEMORY_IFC#(Addr, Record) dataStore <- mkScratchpad(`VDEV_SCRATCH_MATRIXA, SCRATCHPAD_CACHED);

    Reg#(Bit#(TLog#(RecordsPerBlock))) readRespCount  <- mkReg(0);
    Reg#(Bit#(TAdd#(1,TLog#(RecordsPerBlock)))) writeCount <- mkReg(recordsPerMemRequest);

    Reg#(Addr) readAddr <- mkReg(0);
    Reg#(Addr) writeAddr <- mkReg(0);

    // need some credit fifo for reads. 
    FIFOF#(Record) readRespFIFO   <- mkSizedFIFOF(128);
    FIFOF#(Record) writeFIFO      <- mkSizedFIFOF(128);
    FIFOF#(Bit#(1)) creditOutfifo <- mkSizedFIFOF(128);

    rule doReads(readRespCount > 0);
        readRespCount <= readRespCount + 1;
        dataStore.readReq(readAddr + zeroExtend(readRespCount));
        creditOutfifo.enq(0);
    endrule

    rule doResps;
        let data <- dataStore.readRsp();
	readRespFIFO.enq(data);
    endrule 

    rule doWrites(writeCount < recordsPerMemRequest);
        writeCount <= writeCount + 1;
        dataStore.write(writeAddr + zeroExtend(writeCount), writeFIFO.first);
	writeFIFO.deq;
    endrule

    // This is conservative...
    method Bool readsPending(); 
        return readRespCount != 0 || creditOutfifo.notEmpty;
    endmethod

    method Bool writesPending();
        return  writeCount <  recordsPerMemRequest || writeFIFO.notEmpty;
    endmethod

    interface Read read;

        method Action readReq(Addr addr) if(readRespCount == 0);
            readRespCount <= 1;
            dataStore.readReq(addr);
            creditOutfifo.enq(0);	
	    readAddr <= addr;
        endmethod 

        method ActionValue#(Record) read();
           creditOutfifo.deq;
           readRespFIFO.deq;
           return readRespFIFO.first;
        endmethod

    endinterface


    interface Write write;
 
        method Action writeReq(Addr addr) if(writeCount == recordsPerMemRequest);
            writeCount <= 0;
	    writeAddr  <= addr;
        endmethod

        method write = writeFIFO.enq;

    endinterface

endmodule





