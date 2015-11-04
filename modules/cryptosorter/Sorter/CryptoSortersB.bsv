/*
Copyright (c) 2015 Intel Corporation.

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


module [CONNECTED_MODULE] mkCryptoSortersB (Empty);

   for(Integer i = 1; i < `SORTERS; i = i + 2)
   begin
       mkSorter(i);
   end

endmodule
