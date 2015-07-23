#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <iomanip>
#include <bitset>
#include <unistd.h>
using namespace std;

const unsigned int dataByteWidth = 1;
const unsigned int dataWidth = 8*dataByteWidth;

uint64_t calVal(uint64_t x1, uint64_t x2, uint64_t x3, uint64_t x4, uint64_t x5)
{
    int64_t y1 = int64_t(bitset<dataWidth>(x1).to_ulong());
    int64_t y2 = int64_t(bitset<dataWidth>(x2).to_ulong());
    int64_t y3 = int64_t(bitset<dataWidth>(x3).to_ulong());
    int64_t y4 = int64_t(bitset<dataWidth>(x4).to_ulong());
    int64_t y5 = int64_t(bitset<dataWidth>(x5).to_ulong());
    int64_t y  = int64_t(bitset<dataWidth>(y1+y3+y4+y5-3*y2).to_ulong());
    return uint64_t(y);
}

void printUsage(char* programName)
{
    cout<<"Usage: "<< programName <<" <heat frame x size> <heat frame y size> [-g] [-i iter] [-p partition]"<<endl;
}

template <typename T>
string numberToString ( T Number )
{
   ostringstream ss;
   ss << Number;
   return ss.str();
}

int main ( int argc, char *argv[] )
{
    if ( argc < 3 )
    {
        printUsage(argv[0]);
    }
    else
    {
        unsigned int frameSizeX = 0;
        unsigned int frameSizeY = 0;
        bool genGoldenAnswer = false;
        unsigned int iter = 16;
        unsigned int partition = 1;

        int opterr = 0;
        int c;
        while ((c = getopt (argc, argv, "gi:p:")) != -1)
        {            
            switch (c)
            {
                case 'g': genGoldenAnswer = true; break;
                case 'i': iter = atoi(optarg); break;
                case 'p': partition = atoi(optarg); break;
                case '?':
                    if (optopt == 'i' || optopt == 'p')
                      fprintf (stderr, "Option -%c requires an argument.\n", optopt);
                    else if (isprint (optopt))
                      fprintf (stderr, "Unknown option `-%c'.\n", optopt);
                    else
                      fprintf (stderr,
                               "Unknown option character `\\x%x'.\n",
                               optopt);
                    printUsage(argv[0]);
                    return 1;
                default: printUsage(argv[0]); return 1;
            }
        }
        
        if (argc <= optind+1)
        {
            printUsage(argv[0]);
            return 1;
        }
        else
        {
            frameSizeX = atoi(argv[optind]);         
            frameSizeY = atoi(argv[optind+1]);         
        }
        
        cout<<"Heat transfer: "<<frameSizeX<<"x"<<frameSizeY<<" partition: "<< partition<<endl;
       
        if (genGoldenAnswer)
        {
            cout<<"generate golden answer: iter = "<<iter<<endl;
        }

        stringstream fileBaseName;
        fileBaseName << "../benchmark/heat_transfer_"<<frameSizeX<<"x"<<frameSizeY<<"_";
        stringstream iterName;
        iterName << "iter"<<iter<<"_";
        
        // generate frames
        uint64_t** frames[2];

        if (genGoldenAnswer)
        {
            frames[0] = new uint64_t* [frameSizeY];
            frames[1] = new uint64_t* [frameSizeY];
            for (unsigned int i = 0; i < frameSizeY; i++)
            {
                frames[0][i] = new uint64_t [frameSizeX];
                frames[1][i] = new uint64_t [frameSizeX];
            }
        }

        ofstream outfile;
        ofstream outfileHex;
        
        if (partition == 1)
        {
            outfile.open((fileBaseName.str()+string("input.dat")).c_str(), ios::out | ios::binary);
            outfileHex.open((fileBaseName.str()+string("input.hex")).c_str(), ios::out);
        }
        else
        {
            outfile.open((fileBaseName.str()+string("input_p0.dat")).c_str(), ios::out | ios::binary);
            outfileHex.open((fileBaseName.str()+string("input_p0.hex")).c_str(), ios::out);
        }

        unsigned int partition_points = frameSizeX * frameSizeY / partition;
        unsigned int total_points = 0;
        unsigned int total_partition = 0;

        for (unsigned int y = 0; y < frameSizeY; y++)
        {
            for (unsigned int x = 0; x < frameSizeX; x++)
            {
                if (total_points == partition_points)
                {
                    total_points = 0;
                    total_partition++;
                    outfile.close();
                    outfile.open((fileBaseName.str()+string("input_p")+numberToString(total_partition)+string(".dat")).c_str(), ios::out | ios::binary);
                    outfileHex.close();
                    outfileHex.open((fileBaseName.str()+string("input_p")+numberToString(total_partition)+string(".hex")).c_str(), ios::out);
                }
                int val = rand() % (1<<dataWidth);
                int z_val = 0;
                if ((x == 0) || (x == (frameSizeX-1)) || (y == 0) || (y == (frameSizeY-1)) ) //boundaries
                {
                    val = 0;
                }
                outfile.write((char*)&val, dataByteWidth);
                outfile.write((char*)&z_val, dataByteWidth);
                outfileHex << hex << setfill('0') << setw(2) << val <<" ";
                outfileHex << hex << setfill('0') << setw(2) << z_val <<" ";
                if (genGoldenAnswer)
                {
                    frames[0][y][x] = (uint64_t)val;
                    frames[1][y][x] = 0;
                }
                total_points++;
            }
            outfileHex << endl;
        }
        outfile.close();
        outfileHex.close();
        
        if (genGoldenAnswer)
        {
            for (unsigned int t = 0; t < iter; t++ )
            {
                for (unsigned int y = 1; y < (frameSizeY-1); y++)
                {
                    for (unsigned int x = 1; x < (frameSizeX-1); x++)
                    {
                        uint64_t a1 = frames[t%2][y][x-1];
                        uint64_t a2 = frames[t%2][y][x];
                        uint64_t a3 = frames[t%2][y-1][x];
                        uint64_t a4 = frames[t%2][y+1][x];
                        uint64_t a5 = frames[t%2][y][x+1];
                        frames[(t+1)%2][y][x] = calVal(a1, a2, a3, a4, a5);   
                    }
                }
            }
            outfile.open((fileBaseName.str()+string("output_")+iterName.str()+string("golden.dat")).c_str(), ios::out | ios::binary);
            outfileHex.open((fileBaseName.str()+string("output_")+iterName.str()+string("golden.hex")).c_str(), ios::out);
            for (unsigned int y = 0; y < frameSizeY; y++)
            {
                for (unsigned int x = 0; x < frameSizeX; x++)
                {
                    uint64_t outVal0 = frames[0][y][x];
                    uint64_t outVal1 = frames[1][y][x];
                    outfile.write((char*)&outVal0, dataByteWidth);
                    outfile.write((char*)&outVal1, dataByteWidth);
                    outfileHex << hex << setfill('0') << setw(2) << outVal0 <<" ";
                    outfileHex << hex << setfill('0') << setw(2) << outVal1 <<" ";
                }
                outfileHex << endl;
            }
            outfile.close();
            outfileHex.close();
            
            for (unsigned int i = 0; i < frameSizeY; i++)
            {
                delete [] frames[0][i];
                delete [] frames[1][i];
            }
            delete [] frames[0];
            delete [] frames[1];
        }
    }
    
    return 0;
}

