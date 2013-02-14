//----------------------------------------------------------------------//
// The MIT License 
// 
// Copyright (c) 2009 MIT
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
//
// Author: Abhinav Agarwal, Asif Khan, Muralidaran Vijayaraghavan
//
//----------------------------------------------------------------------//

import Types::*;
import FIFOF::*;
import FixedPointNew::*;
import Vector::*;
import Counter::*;

interface Multiplier;
    method Action put(Data x, Data y);
    method ActionValue#(Data) get();
endinterface

typedef 4 PipeDepth;
typedef TAdd#(PipeDepth, 1) PipeDepth1;
typedef TAdd#(TLog#(PipeDepth), 1) LogPipeDepth;
typedef TMul#(IntegralWidth, 2) DoubleIWidth;
typedef TMul#(FractionWidth, 2) DoubleFWidth;
typedef FixedPoint#(DoubleIWidth, DoubleFWidth) DoubleData;

(*synthesize*)
module mkMultiplier (Multiplier);
    FIFOF#(Tuple2#(Data,Data)) in <- mkFIFOF;
    FIFOF#(Data)              out <- mkFIFOF;

    Counter#(LogPipeDepth)  count <- mkCounter(0);

    MultRaw                  mult <- mkMultRaw;

    Reg#(Bit#(64)) counter <- mkReg(0);
    rule counterup;
        counter <= counter + 1;
    endrule

    Bit#(LogPipeDepth) maxCount = 2;

    rule sendValid(in.notEmpty && count.value < maxCount);
        match {.x,.y} = in.first;
        in.deq;
        mult.put(True, x,y);
        count.up;
    endrule

    rule sendInvalid(!in.notEmpty || count.value == maxCount);
        mult.put(False, 0, 0);
    endrule

    match {.valid, .val} = mult.get;
    rule receive(valid);
        out.enq(val);
    endrule

    method Action put(Data x, Data y);
        in.enq(tuple2(x,y));
    endmethod

    method ActionValue#(Data) get;
        count.down;
        out.deq;
        return out.first;
    endmethod
endmodule

interface MultRaw;
    method Action put(Bool _valid, Data _x, Data _y);
    method Tuple2#(Bool, Data) get();
endinterface

(*synthesize*)
module mkMultRaw (MultRaw);

    Reg#(Data) x <- mkRegU();
    Reg#(Data) y <- mkRegU();

    Vector#(PipeDepth, Reg#(DoubleData)) pipedOutput <- replicateM(mkRegU);
    Vector#(PipeDepth1, Reg#(Bool))            valid <- replicateM(mkReg(False));

    rule propagate;
        pipedOutput[0] <= fxptUMult(x,y);
        for(Integer i = 1; i < valueOf(PipeDepth); i=i+1)
        begin
            pipedOutput[i] <= pipedOutput[i-1];
            valid[i] <= valid[i-1];
        end
        valid[valueOf(PipeDepth)] <= valid[valueOf(PipeDepth)-1];
    endrule

    method Action put(Bool _valid, Data _x, Data _y);
        x <= _x;
        y <= _y;
        valid[0] <= _valid;
    endmethod

    method Tuple2#(Bool, Data) get();
        return tuple2(valid[valueOf(PipeDepth)], fxptTruncate(pipedOutput[valueOf(PipeDepth)-1]));
    endmethod
endmodule

