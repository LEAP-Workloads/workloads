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

*/


package mkMemArb;


import MemTypes::*;
import IMemArb::*;
import FIFOF::*;
import FIFO::*;
import BFIFO::*;
import ClientServer::*;
import GetPut::*;
import GetPutExt::*;

typedef enum { REQ0, REQ1 } ReqPtr deriving(Eq,Bits);

(* synthesize *)
module mkMemArb( IMemArb );

  //-----------------------------------------------------------
  // State

  FIFOF#(MainMemReq) req0Q  <- mkBFIFOF1();
  FIFO#(MainMemResp) resp0Q <- mkBFIFO1();

  FIFOF#(MainMemReq) req1Q  <- mkBFIFOF1();
  FIFO#(MainMemResp) resp1Q <- mkBFIFO1();

  FIFO#(MainMemReq)  mreqQ  <- mkBFIFO1();
  FIFO#(MainMemResp) mrespQ <- mkBFIFO1();

  Reg#(ReqPtr) nextReq <- mkReg(REQ0);

  //-----------------------------------------------------------
  // Some wires

  let req0avail = req0Q.notEmpty();
  let req1avail = req1Q.notEmpty();
  
  //-----------------------------------------------------------
  // Rules

  rule chooseReq0 ( req0avail && (!req1avail || (nextReq == REQ0)) );

    // Rewrite tag field if this is a load ...
    MainMemReq mreq
     = case ( req0Q.first() ) matches
	 tagged LoadReq  .ld : return LoadReq { tag:0, addr:ld.addr };
       endcase;

    // Send out the request
    mreqQ.enq(mreq);
    nextReq <= REQ1;
    req0Q.deq();

  endrule

  rule chooseReq1 ( req1avail && (!req0avail || (nextReq == REQ1)) );

    // Rewrite tag field if this is a load ...
    MainMemReq mreq 
     = case ( req1Q.first() ) matches
         tagged LoadReq  .ld : return LoadReq { tag:1, addr:ld.addr };
       endcase;

    // Send out the request
    mreqQ.enq(mreq);
    nextReq <= REQ0;
    req1Q.deq();

  endrule

  rule returnResp;

    // Use tag to figure out where to send response
    mrespQ.deq();
    let tag 
     = case ( mrespQ.first() ) matches
	 tagged LoadResp  .ld : return ld.tag;
       endcase;
     
    if ( tag == 0 ) 
      resp0Q.enq(mrespQ.first());                                    
    else
      resp1Q.enq(mrespQ.first());

  endrule

  //-----------------------------------------------------------
  // Methods
  
  interface Server cache0_server;
    interface Put request  = fifofToPut(req0Q);
    interface Get response = fifoToGet(resp0Q);
  endinterface

  interface Server cache1_server;
    interface Put request  = fifofToPut(req1Q);
    interface Get response = fifoToGet(resp1Q);
  endinterface

  interface Client mmem_client;
    interface Get request  = fifoToGet(mreqQ);
    interface Put response = fifoToPut(mrespQ);
  endinterface

endmodule

endpackage
