/*
Copyright (c) 2009 MIT

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

Author: Myron King.
*/

import PLBMaster::*;
import PLBMasterDefaultParameters::*;
import FIFO::*;
import GetPut::*;
import MemTypes::*;
import ClientServer::*;
import Connectable::*;
import ClientServerUtils::*;

// this shim sits between the PLB and the cache.

interface PLBShim#(type mem_req_t, type mem_resp_t);
   interface Server#(mem_req_t,mem_resp_t) mem_server;   
endinterface


module mkPLBShim#(PLBMaster plbMaster) (PLBShim#(MainMemReq,MainMemResp));
   
   Reg#(Bit#(TAdd#(1,TLog#(BeatsPerBurst))))  burstCnt <- mkReg(0);
   FIFO#(Bit#(MainMemTagSz)) main_tags                 <- mkFIFO();

   FIFO#(MainMemReq)  cache_to_plb <- mkFIFO();
   FIFO#(MainMemResp) plb_to_cache <- mkFIFO();
   
   // only doing loads
   rule req_to_plb (burstCnt==0);
      let req = cache_to_plb.first();      
      cache_to_plb.deq();
      case (req) matches
	 tagged LoadReq .ld :
	    begin
	       // plb master takes word addresses, hence the shift by two
	       let cmd = tagged LoadPage zeroExtend((ld.addr)>>2);	 
	       main_tags.enq(ld.tag);
	       plbMaster.plbMasterCommandInput.put(cmd);
	       $display("req_to_plb %x", ld.addr);
               //$display("burstCnt %d", valueOf(BeatsPerBurst));
	       burstCnt <= fromInteger(valueOf(BeatsPerBurst));
	    end
      endcase
   endrule
   
   rule resp_from_plb (burstCnt > 0);
      let word <- plbMaster.wordOutput.get();
      //$display("resp_from_plb %x", word);
      burstCnt <= burstCnt-1;
      let resp = tagged LoadResp {tag:main_tags.first(),data:{word[31:0],word[63:32]}};
      plb_to_cache.enq(resp);
      if (burstCnt-1 ==0)
	 main_tags.deq();
   endrule   
   
   interface Server mem_server = putGetToServer(fifoToPut(cache_to_plb),fifoToGet(plb_to_cache));
      
endmodule
