#include "xaxidma.h"
#include "xparameters.h"
#include "sleep.h"
#include "xil_cache.h"
#include "xil_io.h"
#include "xscugic.h"
#include "ImageData.h"  // Your header file with imageData array
#include "xuartps.h"
#include "xil_printf.h"

#define IMG_WIDTH        512
#define IMG_HEIGHT       512
#define IMG_CHANNELS     3
#define imageSize        (IMG_WIDTH * IMG_HEIGHT * IMG_CHANNELS)
#define CHUNK_SIZE       (512 * IMG_CHANNELS)  // 512 pixels per chunk (1536 bytes)

// Function prototypes
u32 checkIdle(u32 baseAddress, u32 offset);
void sendImageChunkDMA(XAxiDma *DmaInstance);
int SetupInterruptSystem(XScuGic *IntcInstancePtr, XAxiDma *AxiDmaPtr);

// Global variables
XScuGic IntcInstance;
XAxiDma myDma;
XUartPs myUart;
volatile int dmaTransferDone = 0;
volatile int currentChunk = 0;
volatile int processingComplete = 0;

// ISR Prototypes
static void imageProcISR(void *CallBackRef);
static void dmaTxISR(void *CallBackRef);

int main() {
    u32 status;
    u32 totalTransmittedBytes = 0;

    xil_printf("Starting Image Processing System...\n\r");

    // ------------------ UART Initialization ------------------
    XUartPs_Config *myUartConfig = XUartPs_LookupConfig(XPAR_PS7_UART_1_DEVICE_ID);
    if (myUartConfig == NULL) {
        xil_printf("UART config lookup failed...\n\r");
        return XST_FAILURE;
    }

    status = XUartPs_CfgInitialize(&myUart, myUartConfig, myUartConfig->BaseAddress);
    if (status != XST_SUCCESS) {
        xil_printf("UART initialization failed...\n\r");
        return XST_FAILURE;
    }

    status = XUartPs_SetBaudRate(&myUart, 115200);
    if (status != XST_SUCCESS) {
        xil_printf("UART baudrate init failed....\n\r");
        return XST_FAILURE;
    }

    xil_printf("UART initialized successfully\n\r");

    // ------------------ DMA Initialization ------------------
    XAxiDma_Config *myDmaConfig = XAxiDma_LookupConfig(XPAR_AXI_DMA_0_DEVICE_ID);
    if (myDmaConfig == NULL) {
        xil_printf("DMA config lookup failed\n\r");
        return XST_FAILURE;
    }

    status = XAxiDma_CfgInitialize(&myDma, myDmaConfig);
    if (status != XST_SUCCESS) {
        xil_printf("DMA initialization failed\n\r");
        return XST_FAILURE;
    }

    // Check if DMA is in Simple mode
    if (XAxiDma_HasSg(&myDma)) {
        xil_printf("DMA is in SG mode, expected Simple mode\n\r");
        return XST_FAILURE;
    }

    xil_printf("DMA initialized successfully\n\r");

    // ------------------ Interrupt System Setup ------------------
    status = SetupInterruptSystem(&IntcInstance, &myDma);
    if (status != XST_SUCCESS) {
        xil_printf("Interrupt system setup failed\n\r");
        return XST_FAILURE;
    }

    xil_printf("Interrupt system initialized successfully\n\r");

    // ------------------ Image Processing Loop ------------------
    // Flush cache to ensure DMA reads the correct data
    Xil_DCacheFlushRange((UINTPTR)image_data, imageSize);

    xil_printf("Starting image processing with %d total chunks...\n\r", 
               (imageSize + CHUNK_SIZE - 1) / CHUNK_SIZE);

    // Reset global variables
    currentChunk = 0;
    dmaTransferDone = 0;
    processingComplete = 0;

    // Start first DMA transfer
    sendImageChunkDMA(&myDma);

    // Wait for all processing to complete
    while (!processingComplete) {
        // Main loop waits for processing completion
    }

    xil_printf("Image processing completed. Starting UART transmission...\n\r");

    // ------------------ Send Image via UART ------------------
    totalTransmittedBytes = 0;
    while (totalTransmittedBytes < imageSize) {
        u32 remainingBytes = imageSize - totalTransmittedBytes;
        u32 chunkSize = (remainingBytes > 512) ? 512 : remainingBytes;
        
        XUartPs_Send(&myUart, (u8 *)&image_data[totalTransmittedBytes], chunkSize);
        totalTransmittedBytes += chunkSize;
        
        // Progress indication
        if (totalTransmittedBytes % (32 * 1024) == 0) {
            xil_printf("UART: Transmitted %d/%d bytes\n\r", totalTransmittedBytes, imageSize);
        }
        
        usleep(1000);  // Small delay to prevent UART overrun
    }

    xil_printf("Image transmission over UART completed (%d bytes).\n\r", totalTransmittedBytes);
    xil_printf("System ready for next operation...\n\r");

    // Main loop - system remains active for future operations
    while (1) {
        // You can add additional functionality here
        sleep(1);
    }

    return XST_SUCCESS;
}

// ------------------ Setup Interrupt System ------------------
int SetupInterruptSystem(XScuGic *IntcInstancePtr, XAxiDma *AxiDmaPtr) {
    int Status;

    // Initialize interrupt controller
    XScuGic_Config *IntcConfig = XScuGic_LookupConfig(XPAR_SCUGIC_SINGLE_DEVICE_ID);
    if (IntcConfig == NULL) {
        return XST_FAILURE;
    }

    Status = XScuGic_CfgInitialize(IntcInstancePtr, IntcConfig, IntcConfig->CpuBaseAddress);
    if (Status != XST_SUCCESS) {
        return XST_FAILURE;
    }

    // Connect DMA MM2S (TX) interrupt
    Status = XScuGic_Connect(IntcInstancePtr, 
                            XPAR_FABRIC_AXI_DMA_0_MM2S_INTROUT_INTR,
                            (Xil_ExceptionHandler)dmaTxISR, 
                            AxiDmaPtr);
    if (Status != XST_SUCCESS) {
        return XST_FAILURE;
    }

    // Connect Image Processing interrupt (if available)
    #ifdef XPAR_FABRIC_IMAGEPROCESS_0_O_INTR_INTR
    Status = XScuGic_Connect(IntcInstancePtr, 
                            XPAR_FABRIC_IMAGEPROCESS_0_O_INTR_INTR,
                            (Xil_ExceptionHandler)imageProcISR, 
                            AxiDmaPtr);
    if (Status != XST_SUCCESS) {
        return XST_FAILURE;
    }
    XScuGic_Enable(IntcInstancePtr, XPAR_FABRIC_IMAGEPROCESS_0_O_INTR_INTR);
    #endif

    // Enable DMA interrupt
    XScuGic_Enable(IntcInstancePtr, XPAR_FABRIC_AXI_DMA_0_MM2S_INTROUT_INTR);

    // Enable DMA interrupt in DMA engine
    XAxiDma_IntrEnable(AxiDmaPtr, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DMA_TO_DEVICE);

    // Initialize and enable exceptions
    Xil_ExceptionInit();
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
                                (Xil_ExceptionHandler)XScuGic_InterruptHandler,
                                IntcInstancePtr);
    Xil_ExceptionEnable();

    return XST_SUCCESS;
}

// ------------------ DMA Image Chunk Transfer ------------------
void sendImageChunkDMA(XAxiDma *DmaInstance) {
    u32 status;
    u32 bytesRemaining = imageSize - (currentChunk * CHUNK_SIZE);
    u32 transferSize = (bytesRemaining > CHUNK_SIZE) ? CHUNK_SIZE : bytesRemaining;
    u32 sourceAddr = (u32)&image_data[currentChunk * CHUNK_SIZE];

    if (bytesRemaining == 0) {
        xil_printf("No more data to transfer\n\r");
        processingComplete = 1;
        return;
    }

    // Ensure cache coherency
    Xil_DCacheFlushRange(sourceAddr, transferSize);

    dmaTransferDone = 0;

    status = XAxiDma_SimpleTransfer(DmaInstance, sourceAddr, transferSize, XAXIDMA_DMA_TO_DEVICE);
    if (status != XST_SUCCESS) {
        xil_printf("DMA transfer failed at chunk %d (status: 0x%x)\n\r", currentChunk, status);
        processingComplete = 1;  // Stop processing on error
    } else {
        xil_printf("DMA transfer started: chunk %d, size %d bytes\n\r", currentChunk, transferSize);
    }
}

// ------------------ Check if DMA is idle ------------------
u32 checkIdle(u32 baseAddress, u32 offset) {
    u32 status = XAxiDma_ReadReg(baseAddress, offset);
    return (status & XAXIDMA_IDLE_MASK);
}

// ------------------ DMA TX Complete ISR ------------------
static void dmaTxISR(void *CallBackRef) {
    u32 IrqStatus;
    XAxiDma *AxiDmaInst = (XAxiDma *)CallBackRef;

    // Read pending interrupts
    IrqStatus = XAxiDma_IntrGetIrq(AxiDmaInst, XAXIDMA_DMA_TO_DEVICE);

    // Acknowledge pending interrupts
    XAxiDma_IntrAckIrq(AxiDmaInst, IrqStatus, XAXIDMA_DMA_TO_DEVICE);

    if (!(IrqStatus & XAXIDMA_IRQ_ALL_MASK)) {
        return;  // No interrupt for us
    }

    if (IrqStatus & XAXIDMA_IRQ_ERROR_MASK) {
        xil_printf("DMA Error interrupt occurred\n\r");
        processingComplete = 1;
        return;
    }

    if (IrqStatus & XAXIDMA_IRQ_IOC_MASK) {
        // DMA transfer completed
        dmaTransferDone = 1;
        currentChunk++;
        
        // Check if more chunks need to be sent
        if (currentChunk * CHUNK_SIZE < imageSize) {
            sendImageChunkDMA(AxiDmaInst);
        } else {
            xil_printf("All DMA chunks completed (%d chunks)\n\r", currentChunk);
            processingComplete = 1;
        }
    }
}

// ------------------ Image Processing Complete ISR ------------------
static void imageProcISR(void *CallBackRef) {
    XAxiDma *AxiDmaInst = (XAxiDma *)CallBackRef;
    
    xil_printf("Image processing interrupt received\n\r");
    
    // Check if DMA is idle before starting next transfer
    if (dmaTransferDone && (currentChunk * CHUNK_SIZE < imageSize)) {
        sendImageChunkDMA(AxiDmaInst);
    } else if (currentChunk * CHUNK_SIZE >= imageSize) {
        xil_printf("All processing completed via processing ISR\n\r");
        processingComplete = 1;
    }
}
