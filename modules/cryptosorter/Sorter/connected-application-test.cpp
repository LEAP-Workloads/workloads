#include <stdio.h>
#include <sstream>
#include <time.h>
#include "awb/provides/stats_service.h"
#include "awb/rrr/client_stub_CRYPTOSORTERCONTROLRRR.h"
#include "awb/provides/connected_application.h"
#include "awb/provides/cryptosorter_sorter.h"

using namespace std;


// constructor                                                                                                                      
CONNECTED_APPLICATION_CLASS::CONNECTED_APPLICATION_CLASS(VIRTUAL_PLATFORM vp)
  
{
    clientStub = new CRYPTOSORTERCONTROLRRR_CLIENT_STUB_CLASS(NULL);
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
    OUT_TYPE_ReadCycleCount result;
   
    // Send a start command down. 
    // First arg controls the size of the sort list (1 << size)
    // Second controls the kind of list generated
    // 0 - constant
    // 1 - ascending order
    // 2 - descending order
    // 3 - random
    // Third - a seed for random generation of lists 
    
    int logSize = SORTER_TEST_SORTING_SIZE_LOG;
    int style = SORTER_TEST_SORTING_STYLE;
    int seed = 1;

    if (SORTER_TEST_SWEEP == 1)
    {
        for(logSize = 7; logSize < 19; logSize++) {
            for(style = 0; style < 4; style++) {

                clientStub->PutInstruction(logSize,style,seed,0);
                // Wait for done
                result = clientStub->ReadCycleCount(0);

                if (SORTER_INDIVIDUAL_CYCLE_EN == 0)
                {
                    printf("%d:%d:%llu\n", 1 << logSize, style, result.cycleCount); 
                }
	        }
        }
    }
    else
    {
        // Run style 0 (constant) sorting first to warm up the cache
        clientStub->PutInstruction(logSize,0,seed,0);
        
        // Wait for done
        result = clientStub->ReadCycleCount(0);
        
        // Initialize the sorting test data
        clientStub->PutInstruction(logSize,style,seed,1);
        
        // Wait for initialization done
        result = clientStub->ReadCycleCount(0);
        printf("sorter test initialization done\n"); 
    
        if (SORTER_TEST_INIT_STATS == 1)
        {
            stringstream filename;
            filename << "sorter_test_init.stats";
            STATS_SERVER_CLASS::GetInstance()->DumpStats();
            STATS_SERVER_CLASS::GetInstance()->EmitFile(filename.str());
            STATS_SERVER_CLASS::GetInstance()->ResetStatValues();
        }
        
        // Start main processing
        clientStub->PutInstruction(logSize,style,seed,1);
        // Wait for done
        result = clientStub->ReadCycleCount(0);
                
        if (SORTER_INDIVIDUAL_CYCLE_EN == 0)
        {
            printf("%d:%d:%llu\n", 1 << logSize, style, result.cycleCount); 
        }
    }

    STARTER_SERVICE_SERVER_CLASS::GetInstance()->End(0);
  
    return 0;
}
