#include "xparameters.h"

#include "xaxidma.h"
#include "xscugic.h"
#include "xuartps.h"
#include "xtime_l.h"

#include "sleep.h"
#include "xil_cache.h"
#include "xil_io.h"
#include <stdio.h>

#include "TestImage.h"


#define BAUD_RATE        115200
#define BURST_SIZE       128

#define NUMBER_OF_BYTES  512*512*3
#define IMG_WIDTH        512
#define IMG_HEIGHT       512
#define IMG_SIZE         (IMG_WIDTH * IMG_HEIGHT)
#define NO_OF_PASSES     2

static void ProcessingCompleteISR(void *CallBackRef);

XScuGic Intr_Instance;
int ProcessingComplete = 0;

u8 FinalData[NUMBER_OF_BYTES];  // Contains the processed data converted from 32-bit stream to 8-bit stream

int main() {

    int i;

    u32 status;
    u32 TotalBytesSent = 0;
    u32 BurstSize      = 0;

    XTime StartTime, EndTime;

    //*************************************************************************************************************************************************//
    //                            Initialize and Configure UART
    //*************************************************************************************************************************************************//
    XUartPs_Config *UART_Config;
    XUartPs         UART_Instance;

    UART_Config = XUartPs_LookupConfig(XPAR_PS7_UART_1_DEVICE_ID);                              // Lookup UART configuration
    status      = XUartPs_CfgInitialize(&UART_Instance, UART_Config, UART_Config->BaseAddress); // Initialize UART

    if (status != XST_SUCCESS) {
        xil_printf("UART initialization failed\n");
        return -1;
    }

    status = XUartPs_SetBaudRate(&UART_Instance, BAUD_RATE);                                    // Set UART baud rate

    if (status != XST_SUCCESS) {
        xil_printf("Baud Rate initialization failed\n");
        return -1;
    }


    //*************************************************************************************************************************************************//
    //                            Initialize and Configure DMA
    //*************************************************************************************************************************************************//
    XAxiDma_Config *DMA_Config;
    XAxiDma         DMA_Instance;

    DMA_Config = XAxiDma_LookupConfigBaseAddr(XPAR_AXI_DMA_0_BASEADDR);               // Lookup DMA configuration
    status     = XAxiDma_CfgInitialize(&DMA_Instance, DMA_Config);                    // Initialize DMA

    if (status != XST_SUCCESS) {
        xil_printf("DMA initialization failed\n");
        return -1;
    }

    XAxiDma_IntrEnable(&DMA_Instance, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);   // Enable DMA S2MM interrupt


    //*************************************************************************************************************************************************//
    //                            Initialize and Configure Interrupt Controller
    //*************************************************************************************************************************************************//
    XScuGic_Config *Intr_Config;

    Intr_Config = XScuGic_LookupConfig(XPAR_PS7_SCUGIC_0_DEVICE_ID);                                  // Lookup GIC configuration
    status      = XScuGic_CfgInitialize(&Intr_Instance, Intr_Config, Intr_Config->CpuBaseAddress);    // Initialize GIC

    if (status != XST_SUCCESS) {
        xil_printf("Interrupt controller initialization failed\n");
        return -1;
    }

    XScuGic_SetPriorityTriggerType(&Intr_Instance, XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR, 0xA1, 3); // Set priority and trigger
    status = XScuGic_Connect(&Intr_Instance,
                             XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR,
                             (Xil_InterruptHandler)ProcessingCompleteISR,
                             (void *)&DMA_Instance);                                                  // Connect ISR

    if (status != XST_SUCCESS) {
        xil_printf("Interrupt connection failed\n");
        return -1;
    }

    XScuGic_Enable(&Intr_Instance, XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR);                          // Enable interrupt

    Xil_ExceptionInit();                                                                              // Initialize exceptions
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
                                 (Xil_ExceptionHandler)XScuGic_InterruptHandler,
                                 (void *)&Intr_Instance);                                             // Register exception handler
    Xil_ExceptionEnable();                                                                            // Enable exceptions


    //*************************************************************************************************************************************************//
    //                            Send and receive data to and from Image Processing IP
    //*************************************************************************************************************************************************//

    XTime_GetTime(&StartTime);

    // Configure Transmit and Receive Lines
    status = XAxiDma_SimpleTransfer(&DMA_Instance,
                                    (u32)imageData,
                                    IMG_SIZE * sizeof(u32),
                                    XAXIDMA_DEVICE_TO_DMA);                                          // Configure S2MM (IP -> DDR)

    status = XAxiDma_SimpleTransfer(&DMA_Instance,
                                    (u32)imageData,
                                    IMG_SIZE * NO_OF_PASSES * sizeof(u32),
                                    XAXIDMA_DMA_TO_DEVICE);                                          // Configure MM2S (DDR -> IP)

    if (status != XST_SUCCESS) {
        xil_printf("DMA initialization failed\n");
        return -1;
    }

    while (!ProcessingComplete) { }                                                                  // Wait until processing is complete

    XTime_GetTime(&EndTime);

    // Convert the output data to an 8 bit stream so that it can be transferred via UART
    for (i = 0; i < NUMBER_OF_BYTES; i = i + 3) {
        FinalData[i]   = (u8)(imageData[i/3] >> 16);                                                 // Red pixel value
        FinalData[i+1] = (u8)(imageData[i/3] >> 8);                                                  // Green pixel value
        FinalData[i+2] = (u8)(imageData[i/3]);                                                       // Blue pixel value
    }

   while (TotalBytesSent < NUMBER_OF_BYTES) {
       BurstSize       = XUartPs_Send(&UART_Instance, (u8*)&FinalData[TotalBytesSent], BURST_SIZE);  // Send data over UART
       TotalBytesSent += BurstSize;
       usleep(1000);
   }

    printf("Execution Time = %f ms \n\r", ((EndTime - StartTime) * 1000) / COUNTS_PER_SECOND);       // Display the execution time in milliseconds

    return 1;
}


// Interrupt service routine for when all the processed data is transferred back to DDR
static void ProcessingCompleteISR(void *CallBackRef) {
    XAxiDma_IntrDisable((XAxiDma *)CallBackRef, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);        // Disable interrupt
    XAxiDma_IntrAckIrq((XAxiDma *)CallBackRef, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);         // Acknowledge interrupt

    ProcessingComplete = 1;                                                                          // Flag completion

    XAxiDma_IntrEnable((XAxiDma *)CallBackRef, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);         // Re-enable interrupt
}
