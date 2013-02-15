#include <stdio.h>
#include <sstream>
#include <time.h>
#include "awb/provides/stats_service.h"
#include "awb/rrr/client_stub_CARTPOLCONTROLRRR.h"
#include "awb/provides/connected_application.h"

using namespace std;


// constructor                                                                                                                      
CONNECTED_APPLICATION_CLASS::CONNECTED_APPLICATION_CLASS(VIRTUAL_PLATFORM vp)
  
{
    clientStub = new CARTPOLCONTROLRRR_CLIENT_STUB_CLASS(NULL);
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

struct test{
  int N;
  double theta;
  double R;
};
typedef struct test TESTCASE;


#define PI 3.14159

// main                                                                                                                             
int
CONNECTED_APPLICATION_CLASS::Main()
{
    OUT_TYPE_ReadCycleCount result;
    int N = 20;
    double r = 10.0;
    double theta = PI/6;
    UINT64 r_val = *((UINT64*)&r);
    UINT64 theta_val = *((UINT64*)&theta);
    

    clientStub->PutCommand(N,r_val,theta_val);


            do {
                result = clientStub->ReadCycleCount(0);
		sleep(1);
            }while(!result.done);

    STARTER_DEVICE_SERVER_CLASS::GetInstance()->End(0);
  
    return 0;
}
