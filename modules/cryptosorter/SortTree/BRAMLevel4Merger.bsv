//----------------------------------------------------------------------//
// The MIT License 
// 
// Copyright (c) 2008 Alfred Man Cheuk Ng, mcn02@mit.edu 
// 
// Permission is hereby granted, free of charge, to any person 
// obtaining a copy of this software and associated documentation 
// files (the "Software"), to deal in the Software without 
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//----------------------------------------------------------------------//

// import standard librarys
import Connectable::*;
import GetPut::*;
import FIFO::*;
import StmtFSM::*;
import Vector::*;

`include "asim/provides/librl_bsv.bsh"
`include "awb/provides/multifpga_switch.bsh"

typedef 4 FIFO_SZ_4; 
typedef TLog#(TAdd#(FIFO_SZ_4,1)) TOK_SZ_4;

module mkBRAMLevel4MergerInstance (SortLevel#(16,8,Bit#(TOK_SZ_4),Bit#(TOK_SZ_4),Maybe#(Bit#(RecordWidth))));
   Bit#(FIFO_SZ_4) dntCare = ?;
   let res <- mkBRAMOneLevelMerger(dntCare, notValid, fromMaybe(?), mkZeroCycleScheduler, mkBRAMVLevelFIFO(False));
   return res;
endmodule