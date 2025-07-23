#include "xaxidma.h"
#include "xparameters.h"
#include "sleep.h"
#include "xil_cache.h"
#include "xil_io.h"
#include "xscugic.h"
#include "ImageData.h"
#include "xuartps.h"

#define IMG_WIDTH        512
#define IMG_HEIGHT       512
#define IMG_CHANNELS     3
#define imageSize        (IMG_WIDTH * IMG_HEIGHT * IMG_CHANNELS)
#define CHUNK_SIZE       (512 * IMG_CHANNELS)  // 512 pixels per chunk (1536 bytes)

// Function prototypes
u32 checkIdle(u32 baseAddress, u32 offset);
void sendImageDMA(XAxiDma *DmaInstance);

// Global variables
XScuGic IntcInstance;
XAxiDma myDma;
XUartPs myUart;
volatile int done = 0;
volatile int currentChunk = 0;

// ISR Prototypes
static void imageProcISR(void *CallBackRef);
static void dmaReceiveISR(void *CallBackRef);

int main() {
    u32 status;
    u32 totalTransmittedBytes = 0;

    // ------------------ UART Initialization ------------------
    XUartPs_Config *myUartConfig = XUartPs_LookupConfig(XPAR_PS7_UART_1_DEVICE_ID);
    status = XUartPs_CfgInitialize(&myUart, myUartConfig, myUartConfig->BaseAddress);
    if (status != XST_SUCCESS) {
        xil_printf("Uart initialization failed...\n\r");
        return -1;
    }

    status = XUartPs_SetBaudRate(&myUart, 115200);
    if (status != XST_SUCCESS) {
        xil_printf("Baudrate init failed....\n\r");
        return -1;
    }

    // ------------------ DMA Initialization ------------------
    XAxiDma_Config *myDmaConfig = XAxiDma_LookupConfigBaseAddr(XPAR_AXI_DMA_0_BASEADDR);
    status = XAxiDma_CfgInitialize(&myDma, myDmaConfig);
    if (status != XST_SUCCESS) {
        xil_printf("DMA initialization failed\n");
        return -1;
    }

    // Enable DMA interrupt
    XAxiDma_IntrEnable(&myDma, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);

    // ------------------ Interrupt Controller ------------------
    XScuGic_Config *IntcConfig;
    IntcConfig = XScuGic_LookupConfig(XPAR_PS7_SCUGIC_0_DEVICE_ID);
    status = XScuGic_CfgInitialize(&IntcInstance, IntcConfig, IntcConfig->CpuBaseAddress);
    if (status != XST_SUCCESS) {
        xil_printf("Interrupt controller initialization failed..\n\r");
        return -1;
    }

    // Connect image processing ISR
    XScuGic_SetPriorityTriggerType(&IntcInstance, XPAR_FABRIC_IMAGEPROCESS_0_O_INTR_INTR, 0xA0, 3);
    status = XScuGic_Connect(&IntcInstance, XPAR_FABRIC_IMAGEPROCESS_0_O_INTR_INTR,
                             (Xil_InterruptHandler)imageProcISR, (void *)&myDma);
    if (status != XST_SUCCESS) {
        xil_printf("Interrupt connection failed\n\r");
        return -1;
    }
    XScuGic_Enable(&IntcInstance, XPAR_FABRIC_IMAGEPROCESS_0_O_INTR_INTR);

    // Connect DMA receive ISR
    XScuGic_SetPriorityTriggerType(&IntcInstance, XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR, 0xA1, 3);
    status = XScuGic_Connect(&IntcInstance, XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR,
                             (Xil_InterruptHandler)dmaReceiveISR, (void *)&myDma);
    if (status != XST_SUCCESS) {
        xil_printf("Interrupt connection failed\n\r");
        return -1;
    }
    XScuGic_Enable(&IntcInstance, XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR);

    // Enable exceptions
    Xil_ExceptionInit();
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
                                 (Xil_ExceptionHandler)XScuGic_InterruptHandler,
                                 (void *)&IntcInstance);
    Xil_ExceptionEnable();

    // Flush cache to ensure DMA reads the correct data
    Xil_DCacheFlushRange((UINTPTR)imageData, imageSize);

    // ------------------ Send Full Image via DMA ------------------
    currentChunk = 0;
    sendImageDMA(&myDma);

    // Wait for DMA transfer completion
    while (!done);

    xil_printf("Initial DMA transfer completed.\n\r");

    // ------------------ Send Image via UART ------------------
    totalTransmittedBytes = 0;
    while (totalTransmittedBytes < imageSize) {
        u32 chunk = (imageSize - totalTransmittedBytes > 512) ? 512 : (imageSize - totalTransmittedBytes);
        XUartPs_Send(&myUart, (u8 *)&imageData[totalTransmittedBytes], chunk);
        totalTransmittedBytes += chunk;
        usleep(1000);  // Small delay to prevent UART overrun
    }

    xil_printf("Image transmission over UART completed.\n\r");

    while (1) {
        // Loop forever waiting for interrupts (imageProcISR)
    }
    return 0;
}

// ------------------ DMA Image Transfer ------------------
void sendImageDMA(XAxiDma *DmaInstance) {
    u32 status;
    u32 bytesRemaining = imageSize - (currentChunk * CHUNK_SIZE);
    u32 transferSize = (bytesRemaining > CHUNK_SIZE) ? CHUNK_SIZE : bytesRemaining;

    status = XAxiDma_SimpleTransfer(DmaInstance,
                                    (u32)&imageData[currentChunk * CHUNK_SIZE],
                                    transferSize,
                                    XAXIDMA_DMA_TO_DEVICE);
    if (status != XST_SUCCESS) {
        xil_printf("DMA transfer failed at chunk %d\n", currentChunk);
    } else {
        xil_printf("DMA transfer started: chunk %d\n", currentChunk);
    }
}

// ------------------ Check if DMA is idle ------------------
u32 checkIdle(u32 baseAddress, u32 offset) {
    u32 status;
    status = (XAxiDma_ReadReg(baseAddress, offset)) & XAXIDMA_IDLE_MASK;
    return status;
}

// ------------------ Image Processing ISR ------------------
static void imageProcISR(void *CallBackRef) {
    XScuGic_Disable(&IntcInstance, XPAR_FABRIC_IMAGEPROCESS_0_O_INTR_INTR);

    if (checkIdle(XPAR_AXI_DMA_0_BASEADDR, 0x4)) {
        currentChunk++;
        if (currentChunk * CHUNK_SIZE < imageSize) {
            sendImageDMA((XAxiDma *)CallBackRef);
        } else {
            xil_printf("All DMA chunks sent after interrupt.\n");
            done = 1;
        }
    }

    XScuGic_Enable(&IntcInstance, XPAR_FABRIC_IMAGEPROCESS_0_O_INTR_INTR);
}

// ------------------ DMA Receive ISR ------------------
static void dmaReceiveISR(void *CallBackRef) {
    XAxiDma_IntrDisable((XAxiDma *)CallBackRef, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);
    XAxiDma_IntrAckIrq((XAxiDma *)CallBackRef, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);
    done = 1;
    XAxiDma_IntrEnable((XAxiDma *)CallBackRef, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);
}
