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

typedef enum {
    BANK_A,
    BANK_B
} Bank deriving (Bits, Eq); 

function Integer getMemoryID (Integer memoryIDLogical, Integer bankID);
    let memory_id =  case (memoryIDLogical) matches 
                         0:  return (bankID == 0)? `VDEV_SCRATCH_SORTER_BANK_0  : `VDEV_SCRATCH_SORTER_BANK_1;
                         1:  return (bankID == 0)? `VDEV_SCRATCH_SORTER_BANK_2  : `VDEV_SCRATCH_SORTER_BANK_3; 
                         2:  return (bankID == 0)? `VDEV_SCRATCH_SORTER_BANK_4  : `VDEV_SCRATCH_SORTER_BANK_5;
                         3:  return (bankID == 0)? `VDEV_SCRATCH_SORTER_BANK_6  : `VDEV_SCRATCH_SORTER_BANK_7;
                         4:  return (bankID == 0)? `VDEV_SCRATCH_SORTER_BANK_8  : `VDEV_SCRATCH_SORTER_BANK_9;
                         5:  return (bankID == 0)? `VDEV_SCRATCH_SORTER_BANK_10 : `VDEV_SCRATCH_SORTER_BANK_11;
                         6:  return (bankID == 0)? `VDEV_SCRATCH_SORTER_BANK_12 : `VDEV_SCRATCH_SORTER_BANK_13;
                         7:  return (bankID == 0)? `VDEV_SCRATCH_SORTER_BANK_14 : `VDEV_SCRATCH_SORTER_BANK_15;
                     endcase;
   return memory_id;
endfunction    

module [CONNECTED_MODULE] mkExternalMemory#(Integer memoryIDLogical) (ExternalMemory);

    let recordsPerMemRequest = fromInteger(valueof(RecordsPerMemRequest));
    
    if (memoryIDLogical > 7)
    begin
        error("Sorter ID " + integerToString(memoryIDLogical) + " too large. (Need to register more scratchpad IDs.)");
    end

    let sconfA = defaultValue;
    sconfA.enableStatistics = tagged Valid ("Sorter_" + integerToString(memoryIDLogical) + "_bankA");

    let sconfB = defaultValue;
    sconfB.enableStatistics = tagged Valid ("Sorter_" + integerToString(memoryIDLogical) + "_bankB");

    // we might want to partition this into two address spaces at some point ...
    MEMORY_IFC#(Addr, Record) dataStoreA <- mkScratchpad(fromInteger(getMemoryID(memoryIDLogical,0)), sconfA);
    MEMORY_IFC#(Addr, Record) dataStoreB <- mkScratchpad(fromInteger(getMemoryID(memoryIDLogical,1)), sconfB);

    Reg#(Bit#(TLog#(RecordsPerBlock))) readRespCount  <- mkReg(0);
    Reg#(Bit#(TAdd#(1,TLog#(RecordsPerBlock)))) writeCount <- mkReg(recordsPerMemRequest);

    Reg#(Addr) readAddr <- mkReg(0);
    Reg#(Addr) writeAddr <- mkReg(0);

    // need some credit fifo for reads. 
    FIFOF#(Record) readRespFIFO   <- mkSizedFIFOF(128);
    FIFOF#(Addr) readAddrFIFO     <- mkSizedFIFOF(128);
    FIFOF#(Record) writeDataFIFO  <- mkSizedFIFOF(128);
    FIFOF#(Addr) writeAddrFIFO    <- mkSizedFIFOF(128/valueof(RecordsPerBlock));
    FIFOF#(Addr) creditOutfifo    <- mkSizedFIFOF(128); 
    FIFOF#(Bank) bankDirection    <- mkSizedFIFOF(128);
        
    Addr bank_mask  = fromInteger(valueOf(MemBankSelector))>>6;


    rule doReads(readRespCount > 0);
        let addr = readAddr + zeroExtend(readRespCount);
        readRespCount <= readRespCount + 1;
        if(addr < bank_mask)
        begin 
            dataStoreA.readReq(addr);
            bankDirection.enq(BANK_A);
        end
        else
        begin 
            dataStoreB.readReq(addr);
            bankDirection.enq(BANK_B);
        end
        creditOutfifo.enq(addr);
        if(sorterDebug) 
            $display("Mem Read Request %h", addr);
    endrule

    rule doRespsA(bankDirection.first == BANK_A);
        let data <- dataStoreA.readRsp();
        readRespFIFO.enq(data);
        bankDirection.deq;
    endrule 

    rule doRespsB(bankDirection.first == BANK_B);
        let data <- dataStoreB.readRsp();
        readRespFIFO.enq(data);
        bankDirection.deq;
    endrule 

    rule doWrites(writeCount < recordsPerMemRequest);
        writeCount <= writeCount + 1;
        let addr = writeAddr + zeroExtend(writeCount);

        if(addr < bank_mask)
        begin
            dataStoreA.write(addr, writeDataFIFO.first);
        end
        else
        begin
            dataStoreB.write(addr, writeDataFIFO.first);
        end
        writeDataFIFO.deq;
        if(sorterDebug) 
            $display("Mem Write Address %h %h", addr, writeDataFIFO.first);
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
            if(adjustedAddr < bank_mask)
            begin 
                dataStoreA.readReq(adjustedAddr);
                bankDirection.enq(BANK_A);
            end
            else
            begin 
                dataStoreB.readReq(adjustedAddr);
                bankDirection.enq(BANK_B);
            end
            creditOutfifo.enq(adjustedAddr);    
            readAddr <= adjustedAddr;
            if(sorterDebug) 
                $display("Mem Read Request %h", adjustedAddr);
        endmethod 

        method ActionValue#(Record) read();
           creditOutfifo.deq;
           readRespFIFO.deq;
           if(sorterDebug) 
               $display("Mem Read Response %h %h", creditOutfifo.first, readRespFIFO.first); 
           return readRespFIFO.first;
        endmethod
    endinterface


    interface WriteIfc write;
        method writeReq = writeAddrFIFO.enq;
        method write = writeDataFIFO.enq;
    endinterface

endmodule


