/**
 * @file Image_HazeRemoval_SW_Driver.c
 * @brief Software driver for FPGA-based Image Haze Removal System
 * @description This application interfaces with the Image_HazeRemoval IP core through
 *              AXI-DMA transfers. It handles data movement between DDR memory and the
 *              processing pipeline, manages interrupts, and provides UART output for
 *              processed image data.
 * 
 * @author Rohan M
 * @date 27th August 2025
 * @version 1.0
 * 
 * System Architecture:
 * - ARM Processor (PS) running this software
 * - Image_HazeRemoval IP core in FPGA fabric (PL)
 * - AXI-DMA for high-throughput data transfers
 * - UART for external communication of results
 * - Interrupt-driven processing completion detection
 * 
 * Processing Flow:
 * 1. Initialize system peripherals (UART, DMA, Interrupts)
 * 2. Configure DMA transfers (DDR -> IP -> DDR)
 * 3. Start concurrent MM2S and S2MM transfers
 * 4. Wait for interrupt-driven completion
 * 5. Convert 32-bit pixel data to 8-bit format
 * 6. Transmit results via UART
 * 7. Report execution timing
 */

//==========================================================================================
// SYSTEM INCLUDES
//==========================================================================================
#include "xparameters.h"       // Auto-generated hardware parameters
#include "xaxidma.h"           // AXI-DMA driver functions
#include "xscugic.h"           // ARM Generic Interrupt Controller driver
#include "xuartps.h"           // UART PS driver
#include "xtime_l.h"           // Low-level timing functions
#include "sleep.h"             // Sleep and delay functions
#include "xil_cache.h"         // Cache management functions
#include "xil_io.h"            // Memory-mapped I/O functions
#include <stdio.h>             // Standard I/O functions
#include "TestImage.h"         // Test image data header

//==========================================================================================
// SYSTEM CONFIGURATION CONSTANTS
//==========================================================================================
#define BAUD_RATE        115200     /**< UART communication baud rate (bits per second) */
#define BURST_SIZE       128        /**< UART transmission burst size (bytes per burst)
                                         Optimized to balance throughput and latency */

//==========================================================================================
// IMAGE PROCESSING PARAMETERS
//==========================================================================================
#define NUMBER_OF_BYTES  512*512*3  /**< Total bytes in RGB image (Width × Height × 3 channels) */
#define IMG_WIDTH        512        /**< Image width in pixels */
#define IMG_HEIGHT       512        /**< Image height in pixels */
#define IMG_SIZE         (IMG_WIDTH * IMG_HEIGHT)  /**< Total pixels in image */
#define NO_OF_PASSES     2          /**< Number of processing passes through the image
                                         Pass 1: Atmospheric Light Estimation
                                         Pass 2: Transmission Estimation & Scene Recovery */

//==========================================================================================
// FUNCTION PROTOTYPES
//==========================================================================================
static void ProcessingCompleteISR(void *CallBackRef);

//==========================================================================================
// GLOBAL VARIABLES
//==========================================================================================
XScuGic Intr_Instance;         /**< Global Interrupt Controller instance */
int ProcessingComplete = 0;     /**< Processing completion flag (set by ISR) */

/**
 * @brief Final processed image data buffer
 * @description Stores the converted 8-bit RGB data after processing
 * Format: [R0,G0,B0,R1,G1,B1,...] where each component is 8-bit
 */
u8 FinalData[NUMBER_OF_BYTES];

//==========================================================================================
// MAIN FUNCTION
//==========================================================================================
int main() {
    
    //==================================================================================
    // LOCAL VARIABLES
    //==================================================================================
    int i;                      /**< Loop iterator */
    u32 status;                 /**< Function return status */
    u32 TotalBytesSent = 0;     /**< UART transmission progress counter */
    u32 BurstSize      = 0;     /**< Actual bytes sent per UART burst */
    XTime StartTime, EndTime;   /**< Performance timing variables */

    //==================================================================================
    // UART PERIPHERAL INITIALIZATION AND CONFIGURATION
    // Sets up UART for external communication of processed results
    //==================================================================================
    XUartPs_Config *UART_Config;   /**< UART configuration structure pointer */
    XUartPs         UART_Instance;  /**< UART driver instance */

    // Look up the UART configuration from hardware description
    UART_Config = XUartPs_LookupConfig(XPAR_PS7_UART_1_DEVICE_ID);
    
    // Initialize UART with found configuration
    status = XUartPs_CfgInitialize(&UART_Instance, UART_Config, UART_Config->BaseAddress);
    if (status != XST_SUCCESS) {
        xil_printf("UART initialization failed\n");
        return -1;
    }

    // Configure UART baud rate for reliable communication
    status = XUartPs_SetBaudRate(&UART_Instance, BAUD_RATE);
    if (status != XST_SUCCESS) {
        xil_printf("Baud Rate initialization failed\n");
        return -1;
    }

    //==================================================================================
    // AXI-DMA INITIALIZATION AND CONFIGURATION
    // Sets up high-performance data movement between memory and IP core
    //==================================================================================
    XAxiDma_Config *DMA_Config;    /**< DMA configuration structure pointer */
    XAxiDma         DMA_Instance;   /**< DMA driver instance */

    // Look up DMA configuration using base address
    DMA_Config = XAxiDma_LookupConfigBaseAddr(XPAR_AXI_DMA_0_BASEADDR);
    
    // Initialize DMA controller with found configuration
    status = XAxiDma_CfgInitialize(&DMA_Instance, DMA_Config);
    if (status != XST_SUCCESS) {
        xil_printf("DMA initialization failed\n");
        return -1;
    }

    // Enable DMA Stream-to-Memory-Mapped (S2MM) interrupt
    // This interrupt fires when processed data transfer from IP to DDR completes
    XAxiDma_IntrEnable(&DMA_Instance, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);

    //==================================================================================
    // INTERRUPT CONTROLLER INITIALIZATION AND CONFIGURATION
    // Sets up ARM Generic Interrupt Controller for DMA completion detection
    //==================================================================================
    XScuGic_Config *Intr_Config;   /**< Interrupt controller configuration pointer */

    // Look up interrupt controller configuration
    Intr_Config = XScuGic_LookupConfig(XPAR_PS7_SCUGIC_0_DEVICE_ID);
    
    // Initialize interrupt controller
    status = XScuGic_CfgInitialize(&Intr_Instance, Intr_Config, Intr_Config->CpuBaseAddress);
    if (status != XST_SUCCESS) {
        xil_printf("Interrupt controller initialization failed\n");
        return -1;
    }

    // Configure DMA S2MM interrupt priority and trigger type
    // Priority: 0xA1 (high priority), Trigger: 3 (rising edge)
    XScuGic_SetPriorityTriggerType(&Intr_Instance, 
                                   XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR, 
                                   0xA1, 3);
    
    // Connect interrupt service routine to DMA S2MM interrupt
    status = XScuGic_Connect(&Intr_Instance,
                             XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR,
                             (Xil_InterruptHandler)ProcessingCompleteISR,
                             (void *)&DMA_Instance);
    if (status != XST_SUCCESS) {
        xil_printf("Interrupt connection failed\n");
        return -1;
    }

    // Enable the specific DMA interrupt in the interrupt controller
    XScuGic_Enable(&Intr_Instance, XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR);

    // Initialize and configure ARM exception handling system
    Xil_ExceptionInit();
    
    // Register interrupt controller handler for all interrupts
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
                                 (Xil_ExceptionHandler)XScuGic_InterruptHandler,
                                 (void *)&Intr_Instance);
    
    // Enable ARM processor interrupt handling
    Xil_ExceptionEnable();

    //==================================================================================
    // IMAGE PROCESSING EXECUTION
    // Configure and execute DMA transfers for haze removal processing
    //==================================================================================
    
    // Start performance timing measurement
    XTime_GetTime(&StartTime);

    /**
     * DMA Transfer Configuration:
     * 
     * S2MM (Stream-to-Memory-Mapped): IP -> DDR
     * - Receives processed data from Image_HazeRemoval IP
     * - Transfer size: IMG_SIZE * sizeof(u32) bytes
     * - Each pixel is 32-bit (8-bit per RGB channel + 8-bit unused)
     * 
     * MM2S (Memory-Mapped-to-Stream): DDR -> IP  
     * - Sends input data to Image_HazeRemoval IP
     * - Transfer size: IMG_SIZE * NO_OF_PASSES * sizeof(u32) bytes
     * - NO_OF_PASSES accounts for two-stage processing (ALE + TE_SRSC)
     */
    
    // Configure S2MM transfer (processed data from IP to DDR)
    status = XAxiDma_SimpleTransfer(&DMA_Instance,
                                    (u32)imageData,                    // Destination buffer
                                    IMG_SIZE * sizeof(u32),            // Transfer size
                                    XAXIDMA_DEVICE_TO_DMA);            // Direction: IP -> DDR

    // Configure MM2S transfer (input data from DDR to IP)
    status = XAxiDma_SimpleTransfer(&DMA_Instance,
                                    (u32)imageData,                    // Source buffer
                                    IMG_SIZE * NO_OF_PASSES * sizeof(u32), // Transfer size
                                    XAXIDMA_DMA_TO_DEVICE);            // Direction: DDR -> IP

    if (status != XST_SUCCESS) {
        xil_printf("DMA transfer configuration failed\n");
        return -1;
    }

    // Wait for processing completion (signaled by interrupt)
    // ProcessingComplete flag is set by ProcessingCompleteISR()
    while (!ProcessingComplete) { 
        // Processor remains in low-power state while IP processes data
    }

    // Stop performance timing measurement
    XTime_GetTime(&EndTime);

    //==================================================================================
    // DATA FORMAT CONVERSION
    // Convert 32-bit pixel format to 8-bit RGB format for UART transmission
    //==================================================================================
    
    /**
     * Data Format Conversion:
     * Input:  32-bit words [31:24]=unused, [23:16]=R, [15:8]=G, [7:0]=B
     * Output: 8-bit stream [R0,G0,B0,R1,G1,B1,R2,G2,B2,...]
     * 
     * This conversion is necessary because:
     * 1. UART transmits 8-bit data efficiently
     * 2. External systems expect standard RGB byte format
     * 3. Removes unused upper 8 bits to reduce transmission overhead
     */
    for (i = 0; i < NUMBER_OF_BYTES; i = i + 3) {
        FinalData[i]   = (u8)(imageData[i/3] >> 16);    // Extract Red channel
        FinalData[i+1] = (u8)(imageData[i/3] >> 8);     // Extract Green channel  
        FinalData[i+2] = (u8)(imageData[i/3]);          // Extract Blue channel
    }

    //==================================================================================
    // UART DATA TRANSMISSION
    // Send processed image data to external system via UART
    //==================================================================================
    
    /**
     * Burst Transmission Strategy:
     * - Sends data in BURST_SIZE chunks to optimize throughput
     * - Includes small delay between bursts to prevent buffer overflow
     * - Tracks progress to ensure complete transmission
     * - Handles partial burst transmission on final chunk
     */
    while (TotalBytesSent < NUMBER_OF_BYTES) {
        // Send burst of data (returns actual bytes sent)
        BurstSize = XUartPs_Send(&UART_Instance, 
                                 (u8*)&FinalData[TotalBytesSent], 
                                 BURST_SIZE);
        
        // Update transmission progress
        TotalBytesSent += BurstSize;
        
        // Small delay to prevent UART buffer overflow
        usleep(1000);  // 1ms delay
    }

    //==================================================================================
    // PERFORMANCE REPORTING
    // Calculate and display processing execution time
    //==================================================================================
    
    /**
     * Execution Time Calculation:
     * - StartTime: Captured before DMA transfer initiation
     * - EndTime: Captured after processing completion interrupt
     * - Includes: DMA setup, IP processing time, DMA completion
     * - Excludes: Data format conversion and UART transmission
     */
    printf("Execution Time = %f ms \n\r", 
           ((EndTime - StartTime) * 1000) / COUNTS_PER_SECOND);

    return 1;  // Successful completion
}

//==========================================================================================
// INTERRUPT SERVICE ROUTINE
//==========================================================================================

/**
 * @brief DMA S2MM completion interrupt service routine
 * @description Called when the Image_HazeRemoval IP completes processing and
 *              all processed data has been transferred back to DDR memory.
 *              This ISR manages interrupt acknowledgment and sets completion flag.
 * 
 * @param CallBackRef Pointer to DMA instance (passed during interrupt connection)
 * 
 * ISR Execution Flow:
 * 1. Disable further S2MM interrupts to prevent spurious interrupts
 * 2. Acknowledge the current interrupt to clear interrupt flag
 * 3. Set global completion flag for main thread
 * 4. Re-enable interrupts for potential future operations
 * 
 * Threading Notes:
 * - This ISR runs in interrupt context with higher priority than main()
 * - ProcessingComplete flag provides thread-safe communication with main()
 * - No complex processing should be done in ISR to minimize interrupt latency
 */
static void ProcessingCompleteISR(void *CallBackRef) {
    
    // Cast callback reference to DMA instance pointer
    XAxiDma *DmaPtr = (XAxiDma *)CallBackRef;
    
    // Disable S2MM interrupts temporarily
    // Prevents additional interrupts during ISR execution
    XAxiDma_IntrDisable(DmaPtr, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);
    
    // Acknowledge the interrupt to clear interrupt pending flag
    // Required to prevent interrupt from being serviced repeatedly  
    XAxiDma_IntrAckIrq(DmaPtr, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);

    // Signal main thread that processing is complete
    // This flag is polled by main() to detect completion
    ProcessingComplete = 1;

    // Re-enable S2MM interrupts for potential future transfers
    // System is ready for next processing cycle
    XAxiDma_IntrEnable(DmaPtr, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);
}
