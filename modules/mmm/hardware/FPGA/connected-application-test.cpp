#include <stdio.h>
#include <sstream>
#include <time.h>
#include "awb/provides/stats_service.h"
#include "awb/rrr/client_stub_MMMCONTROLRRR.h"
#include "awb/provides/connected_application.h"
#include "awb/provides/mmm_memory_switch.h"

using namespace std;

#define createSec(m, i, j, x) (m + i*BlockSize*Size*4 + (FU_Number*j+x)*BlockSize*4)

#define createPrim(m, i, j) (m + i*BlockSize*Size*4 + j*BlockSize*4)

// constructor                                                                                                                      
CONNECTED_APPLICATION_CLASS::CONNECTED_APPLICATION_CLASS(VIRTUAL_PLATFORM vp)
  
{
    clientStub = new MMMCONTROLRRR_CLIENT_STUB_CLASS(NULL);
}

// destructor                                                                                                                       
CONNECTED_APPLICATION_CLASS::~CONNECTED_APPLICATION_CLASS()
{
}

// init                                                                                                                             
void
CONNECTED_APPLICATION_CLASS::Init()
{
}

// main                                                                                                                             
int
CONNECTED_APPLICATION_CLASS::Main()
{
    //int Size = 64;
    int Size = 1<<10;
    int BlockSize = 64;
    UInt64 a = (UInt64)aMatrix;
    UInt64 b = (UInt64)bMatrix;
    UInt64 c = (UInt64)cMatrix;

    int FU_Number = (int) FunctionalUnitNumber;

    int BlockNum = Size/BlockSize;
    int LogSize;

    int BigBlockNum = BlockNum/FU_Number;
    int BigBlockRest = BlockNum%FU_Number;

    int response;

    UInt64 inst;    

    switch(Size)
    {
        case 64:
            LogSize = 6;
            break;
        case 128:
            LogSize = 7;
            break;
        case 256:
            LogSize = 8;
            break;
        case 512:
            LogSize = 9;
            break;
        default:
            LogSize = 10;
            break;
    }

    inst = createSetRowSizeInstruction(LogSize);  

    clientStub->PutInstruction(inst);

    int i;
    int j;
    int k;
    int f;
    for(int iters = 0; iters < 4; iters++) {
      clock_t begin, end;
      double time_spent;
      begin = clock();
    for(i = 0; i < BlockNum; i=i+1)
    {
        for(j = 0; j < BigBlockNum; j=j+1)
        {
	    inst = createArithmeticInstruction(All_FU_Mask, Zero);
            clientStub->PutInstruction(inst);
            for(k = 0; k < BlockNum; k=k+1)
            {
                for(f = 0; f < FU_Number; f=f+1)
                {
 	 	   inst = createLoadInstruction((((int)1)<<f), B, createSec(b, k, j, f)); 
		   clientStub->PutInstruction(inst);		  
                }
		   inst = createLoadInstruction(All_FU_Mask, A, createPrim(a, i, k));
		   clientStub->PutInstruction(inst);
		{ 

                }
  
                inst = createArithmeticInstruction(All_FU_Mask, MultiplyAddAccumulate); 
                clientStub->PutInstruction(inst);
		

		
            }
            for(f = 0; f < FU_Number; f=f+1)
            {
              int i = 0;
              inst = createStoreInstruction(f, C, createSec(c, i, j, f));
	      clientStub->PutInstruction(inst);
              free(MEMORY_RRR_SERVER_CLASS::GetInstance()->getResponse());
             
            }
        }
        if(BigBlockRest != 0)
        {
	  inst = createArithmeticInstruction(All_FU_Mask, Zero);
	  clientStub->PutInstruction(inst);

            for(k = 0; k < BlockNum; k=k+1)
            {
                for(f = 0; f < BigBlockRest; f=f+1)
                {
                  inst = createLoadInstruction(((int)1<<f), B, createPrim(b, k, j*FU_Number+f));
		  clientStub->PutInstruction(inst);
 
                }

                inst = createLoadInstruction(All_FU_Mask, A, createPrim(a, i, k));
                clientStub->PutInstruction(inst);

                inst = createArithmeticInstruction(All_FU_Mask, MultiplyAddAccumulate);
                clientStub->PutInstruction(inst);

            }
            for(f = 0; f < BigBlockRest; f=f+1)
            {
              int i = 0;
              inst = createStoreInstruction(f, C, createPrim(c, i, j*FU_Number+f));
	      clientStub->PutInstruction(inst);

              free(MEMORY_RRR_SERVER_CLASS::GetInstance()->getResponse());

            }
        }
    }
      end = clock();
      time_spent = (double)(end - begin) / CLOCKS_PER_SEC;
      printf("Time %d: %f\n", iters, time_spent); 
    }
    STARTER_DEVICE_SERVER_CLASS::GetInstance()->End(0);
  
    return 0;
}
