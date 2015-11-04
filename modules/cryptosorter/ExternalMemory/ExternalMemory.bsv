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
import DefaultValue::*;


`include "awb/provides/cryptosorter_common.bsh"

`include "awb/provides/librl_bsv.bsh"
`include "awb/provides/soft_connections.bsh"
`include "awb/provides/soft_services.bsh"
`include "awb/provides/soft_services_lib.bsh"
`include "awb/provides/soft_services_deps.bsh"
`include "awb/provides/mem_services.bsh"
`include "awb/provides/common_services.bsh"
`include "awb/provides/scratchpad_memory_common.bsh"
`include "awb/dict/VDEV_SCRATCH.bsh"

module [CONNECTED_MODULE] mkExternalMemory#(Integer memoryIDLogical) (ExternalMemory);

//    let recordsPerMemRequest = fromInteger(valueof(RecordsPerMemRequest));
    let recordsPerMemRequest = fromInteger(valueof(RecordsPerBlock));

    let sconf = defaultValue;

    // need to convert into scratchpad space.
    let memoryID = `VDEV_SCRATCH__BASE + memoryIDLogical;

    messageM("sorter memoryID: " + integerToString(memoryID));
    sconf.enableStatistics = tagged Valid ("Sorter_" + integerToString(memoryID));
    sconf.debugLogPath = tagged Valid ("Sorter_" + integerToString(memoryID));

    // we might want to partition this into two address spaces at some point ...
    MEMORY_IFC#(Addr, Record) dataStore <- mkScratchpad(fromInteger(memoryID), sconf);

    Reg#(Bit#(TLog#(RecordsPerBlock))) readRespCount  <- mkReg(0);
    Reg#(Bit#(TAdd#(1,TLog#(RecordsPerBlock)))) writeCount <- mkReg(recordsPerMemRequest);

    Reg#(Addr) readAddr <- mkReg(0);
    Reg#(Addr) writeAddr <- mkReg(0);

    Reg#(Bit#(16)) cycleCount <- mkReg(0);

    // need some credit fifo for reads.                   
    FIFOF#(Record) readRespFIFO   <- mkSizedFIFOF(valueof(MaxOutstandingRequests));
    FIFOF#(Addr) readAddrFIFO     <- mkSizedFIFOF(valueof(MaxOutstandingRequests));
    FIFOF#(Record) writeDataFIFO  <- mkSizedFIFOF(valueof(MaxOutstandingRequests));
    FIFOF#(Addr) writeAddrFIFO    <- mkSizedFIFOF(valueof(MaxOutstandingRequests));
    FIFOF#(Addr) creditOutfifo    <- mkSizedFIFOF(valueof(MaxOutstandingRequests));

    function Rules creditCheck(FIFOF#(fifo_t) fifof, String name);
        return( rules 
                    rule creditCheck (!fifof.notFull && cycleCount == 0);
                        $display("sorter %d %s is full", memoryIDLogical, name);
                    endrule
                endrules);
    endfunction

    addRules(creditCheck(readRespFIFO, "readRespFIFO"));
    addRules(creditCheck(readAddrFIFO, "readAddrFIFO"));
    addRules(creditCheck(writeDataFIFO, "writeDataFIFO"));
    addRules(creditCheck(writeAddrFIFO, "writeAddrFIFO"));
    addRules(creditCheck(creditOutfifo, "creditOutfifo"));

    rule dumpState;
        cycleCount <= cycleCount + 1;
        if(cycleCount == 0)
        begin
            $display("sorter %d write requests %d read requests %d", memoryIDLogical, writeCount, readRespCount);
        end
    endrule

    rule doReads(readRespCount > 0);
        let addr = readAddr + zeroExtend(readRespCount);
        readRespCount <= readRespCount + 1;
        dataStore.readReq(addr);
        creditOutfifo.enq(addr);
        if(sorterDebug) 
            $display("sorter %d Mem Read Request %h", memoryIDLogical, addr);
    endrule

    rule doResps;
        let data <- dataStore.readRsp();
        readRespFIFO.enq(data);
    endrule 

    rule doWrites(writeCount < recordsPerMemRequest);
        writeCount <= writeCount + 1;
        dataStore.write(writeAddr + zeroExtend(writeCount), writeDataFIFO.first);
        writeDataFIFO.deq;
        if(sorterDebug) 
            $display("sorter %d Mem Write Address %h %h, count %d", memoryIDLogical, writeAddr + zeroExtend(writeCount), writeDataFIFO.first, writeCount);
    endrule

    rule startWrite (writeCount == recordsPerMemRequest);
        writeCount <= 0;
        writeAddr  <= writeAddrFIFO.first >> 2;
        writeAddrFIFO.deq;
    endrule

    // This is conservative...
    method Bool readsPending(); 
        return readRespCount != 0 || creditOutfifo.notEmpty;
    endmethod

    method Bool writesPending();
        return  writeCount <  recordsPerMemRequest || writeDataFIFO.notEmpty;
    endmethod

    interface ReadIfc read;
        method Action readReq(Addr addr) if(readRespCount == 0);
            readRespCount <= 1;
            let adjustedAddr = addr >> 2; // Convert to word space.
            dataStore.readReq(adjustedAddr);
            creditOutfifo.enq(adjustedAddr);    
            readAddr <= adjustedAddr;
            if(sorterDebug) 
                $display("sorter %d Mem Read Request %h", memoryIDLogical, adjustedAddr);
        endmethod 

        method ActionValue#(Record) read();
           creditOutfifo.deq;
           readRespFIFO.deq;
           if(sorterDebug) 
               $display("sorter %d Mem Read Response %h %h", memoryIDLogical, creditOutfifo.first, readRespFIFO.first); 
           return readRespFIFO.first;
        endmethod
    endinterface

    interface WriteIfc write;
        method writeReq = writeAddrFIFO.enq;
        method write = writeDataFIFO.enq;
    endinterface

endmodule





