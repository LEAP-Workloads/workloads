#include <stdio.h>
#include <sstream>
#include <time.h>
#include "awb/provides/stats_service.h"
#include "awb/rrr/client_stub_CRYPTOSORTERCONTROLRRR.h"
#include "awb/provides/connected_application.h"

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
    clientStub->PutInstruction(7,2);

    do {
        result = clientStub->ReadCycleCount(0);
    }while(!result.done);

    STARTER_DEVICE_SERVER_CLASS::GetInstance()->End(0);
  
    return 0;
}