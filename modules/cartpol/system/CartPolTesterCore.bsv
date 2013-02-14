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

Author: Kermin Fleming
*/

`define COMPUTE_1

import PLBMaster::*;
import BRAMFeeder::*;
import FIFO::*;
import GetPut::*;
import ICache::*;
import mkDataCacheBlockingBramDoublePumpOverlappedSkinny::*;
import CacheWrapperSplitDoublePump::*;
import MemTypes::*;
import ClientServer::*;
import Connectable::*;
import ClientServerUtils::*;
import PLBShim::*;
import Vector::*;
import IMemArb::*;
import mkMemArb::*;
`ifdef COMPUTE_1
import ComputeTop::*;
import Types::*;
`else
import Compute::*;
import ComputeTypes::*;
`endif
import StmtFSM::*;
import PLBMasterDefaultParameters::*;
import CartPolTesterTypes::*;
import FixedPointNew::*;
import Float::*;

typedef enum{
   Idle,
   Feeding,
   Kickoff,
   Requesting
   } TesterState deriving (Bits,Eq);


module mkCartPolTesterCore#(Feeder feeder, PLBMaster plbMaster, Clock slowClock, Reset slowReset) (Empty);
   
   Reg#(TesterState)                     state <- mkReg(Idle);
   Reg#(Bit#(32))                        cycleCount <- mkReg(0);
   
   // core generates the indices
   `ifdef COMPUTE_1
   ComputeTop computer <- mkComputeTop(slowClock,slowReset);
   `else
   Compute computer <- mkCompute(slowClock, slowReset);
   `endif 

   // this shim sits between the cache and the main memory
   PLBShim#(MainMemReq,MainMemResp) plbShim <- mkPLBShim(plbMaster);

   // cache-wrapper performs address translation and lookup
   Vector#(2,ICache#(DataReq,DoublePumpDataResp)) caches;
   caches[0] <- mkDataCacheBlockingBramDoublePumpOverlappedSkinny(0);
   caches[1] <- mkDataCacheBlockingBramDoublePumpOverlappedSkinny(1);

   CacheWrapper cacheWrap <- mkCacheWrapperSplitDoublePump(caches); 
   mkConnection(cacheWrap.mmem_client, plbShim.mem_server);



   // State for dealing with main mem writeback
   Reg#(PLBAddr)                      storeAddress <- mkRegU; 
   Reg#(Bool)                         hiWord       <- mkReg(False); 
   Reg#(Bit#(32))                    lowerHalfWord <- mkRegU;
   Reg#(Bit#(TAdd#(1,TLog#(WordsPerBurst)))) words <- mkReg(0);
   Reg#(Index)                                rows <- mkRegU;    
   Reg#(Index)                                cols <- mkRegU;    
  


   Reg#(Index) n     <- mkRegU();
   Reg#(Float) r     <- mkRegU();
   Reg#(Float) theta <- mkRegU();   
   
   Stmt s = seq
	       action
		  let dat <- feeder.ppcMessageOutput.get();
		  n <= unpack(truncate(dat));
                  $display("N: %d %d", n, dat);
	       endaction 
	       action
		  let dat <- feeder.ppcMessageOutput.get();
		  r <= unpack({dat,0});
                  $display("32 high bits of R: %h", dat);
	       endaction
	       action
		  let dat <- feeder.ppcMessageOutput.get();
		  r <= unpack(pack(r) + zeroExtend(dat));
                  $display("32 low bits of R: %h", dat);
	       endaction
	       action
		  let dat <- feeder.ppcMessageOutput.get();
		  theta <= unpack({dat,0});
                  $display("32 high bits of Theta: %h", dat);
	       endaction
	       action
		  let dat <- feeder.ppcMessageOutput.get();
		  theta <= unpack(pack(theta) + zeroExtend(dat));
		  state <= Kickoff;
                  $display("32 low bits of Theta: %h", dat);
	       endaction
            endseq;
   
   FSM fsm <- mkFSM(s);
   
   rule countCycle(state == Requesting);
     cycleCount <= cycleCount + 1;
   endrule

   rule start(state==Idle);
      fsm.start;
      $display("CartPolTester: Feeding");
      state <= Feeding;
   endrule

   rule kickoff(state==Kickoff);
//      Data  fixed_r = fromMaybe(?,floatToFixedPoint(r));
//      TData fixed_theta = fromMaybe(?,floatToFixedPoint(theta));
//      $write("CartPolTester: Kickoff r ");
//      fxptWrite(9,fixed_r);
//      $write(", theta ");
//      fxptWrite(9,fixed_theta);
//      $display(", n",n);
      $display("CartPolTester: Kickoff");
      computer.setParam(r,theta,n);
      cacheWrap.reset;
      storeAddress <= fromInteger(valueof(OutputBufferBase));
      rows <= 0;
      cols <= 0;
      cycleCount <= 0;
      state <= Requesting;
   endrule
   
   rule computer_to_wrapper;
      let pos <- computer.getPos();
      $display("CartPolTest: getPos x %d y %d",pos.x,pos.y);
      let coord = Coord{x:pos.x,y:pos.y};
      cacheWrap.mmem_server.request.put(coord);
   endrule
   
   // We must be careful in generating store addresses, lest we deadlock ourselves
   // Moreover, NxN may not be a multiple of 16, so we may need to pad stuff.
   // Push all results in to the PLB master directly
   // Watch out for word endianess
   
   rule resp_from_wrapper(cols < n && state == Requesting); 
      let res <- cacheWrap.mmem_server.response.get;
      $display("resp_from_wrapper %h", res);
       
      if(rows + 1 == n)
        begin
          rows <= 0;
          cols <= cols + 1;
        end
      else
        begin
          rows <= rows + 1;
        end

      // Issue a store only if we have enough data for it
      if(words + 1 == fromInteger(valueof(WordsPerBurst)))
        begin
          $display("Issuing store, rows: %d, cols: %d", rows, cols);
          plbMaster.plbMasterCommandInput.put(tagged StorePage truncate(storeAddress>>2));
          storeAddress <= storeAddress + fromInteger(valueof(WordsPerBurst)*valueof(BytesPerWord));
          words <= 0;
        end
      else
        begin
          words <= words + 1;
        end

      hiWord <= !hiWord;
      if(hiWord)
        begin    
          plbMaster.wordInput.put({lowerHalfWord,res});
        end
      else
        begin
          lowerHalfWord <= res; 
        end   
   endrule


   // Handle the last store to memory
   // Must produce proper number of Words
   rule handleLastStore(cols == n && state == Requesting);
     $display("Firing handle last store n: %d cols: %d", n, cols);
     if(words == 0) // we're already done
       begin
         feeder.ppcMessageInput.put(cycleCount);
         state <= Idle;
         $display("CartPolTester goes to idle");
       end
     else
       begin
         // Issue a store only if we have enough data for it
         if(words + 1 == fromInteger(valueof(WordsPerBurst)))
           begin
             plbMaster.plbMasterCommandInput.put(tagged StorePage truncate(storeAddress>>2));
             storeAddress <= storeAddress + fromInteger(valueof(WordsPerBurst)*valueof(BytesPerWord));
             words <= 0;
             feeder.ppcMessageInput.put(cycleCount);
             $display("CartPolTester goes to idle");
             state <= Idle;
           end
         else
           begin
             words <= words + 1;
           end

         hiWord <= !hiWord;
         if(hiWord)
           begin    
             plbMaster.wordInput.put({lowerHalfWord,?});
           end
         else
           begin
             lowerHalfWord <= ?; 
           end 
       end
   endrule
   
endmodule
