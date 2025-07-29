#include "xaxidma.h"
#include "xparameters.h"
#include "sleep.h"
#include "xil_io.h"
#include "xscugic.h"
#include "imageData.h"
#include "xuartps.h"

#define IMG_WIDTH  512
#define IMG_HEIGHT 512
#define NUM_PIXELS (IMG_WIDTH * IMG_HEIGHT)
#define BYTES_PER_PIXEL 3
#define STREAM_WORD_SIZE 4 // 32-bit AXI stream word
#define IMAGE_STREAM_SIZE (NUM_PIXELS * STREAM_WORD_SIZE) // in bytes
#define RGB_OUTPUT_SIZE (NUM_PIXELS * BYTES_PER_PIXEL)   // 24-bit RGB output size

XScuGic IntcInstance;
XAxiDma myDma;
XUartPs myUart;
volatile int dmaRxDone = 0;
volatile int ipProcessingDone = 0;

// AXI-formatted image data: 32-bit per pixel
u32 imageStream[NUM_PIXELS];     // Data to be sent to IP
u32 processedStream[NUM_PIXELS]; // Data received from IP

// Function Prototypes
static void dmaReceiveISR(void *CallBackRef);
static void ipCompletionISR(void *CallBackRef);
void prepareImageStream(void);
void sendRgbDataToPC(void);

// Main Function
int main() {
    u32 status;

    // UART Setup
    XUartPs_Config *uartConfig = XUartPs_LookupConfig(XPAR_PS7_UART_1_DEVICE_ID);
    status = XUartPs_CfgInitialize(&myUart, uartConfig, uartConfig->BaseAddress);
    if (status != XST_SUCCESS) {
        xil_printf("UART initialization failed\n");
        return -1;
    }
    XUartPs_SetBaudRate(&myUart, 115200);

    // DMA Setup
    XAxiDma_Config *dmaConfig = XAxiDma_LookupConfig(XPAR_AXI_DMA_0_DEVICE_ID);
    status = XAxiDma_CfgInitialize(&myDma, dmaConfig);
    if (status != XST_SUCCESS) {
        xil_printf("DMA initialization failed\n");
        return -1;
    }
    XAxiDma_IntrEnable(&myDma, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);

    // GIC (Interrupt Controller) Setup
    XScuGic_Config *intcConfig = XScuGic_LookupConfig(XPAR_PS7_SCUGIC_0_DEVICE_ID);
    status = XScuGic_CfgInitialize(&IntcInstance, intcConfig, intcConfig->CpuBaseAddress);
    if (status != XST_SUCCESS) {
        xil_printf("Interrupt controller init failed\n");
        return -1;
    }

    // Connect DMA S2MM interrupt
    status = XScuGic_Connect(&IntcInstance, XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR,
                             (Xil_InterruptHandler)dmaReceiveISR, (void *)&myDma);
    if (status != XST_SUCCESS) {
        xil_printf("DMA interrupt connection failed\n");
        return -1;
    }
    XScuGic_Enable(&IntcInstance, XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR);

    status = XScuGic_Connect(&IntcInstance, XPAR_FABRIC_DCP_HAZEREMOVAL_0_O_INTR_INTR,
                             (Xil_InterruptHandler)ipCompletionISR, NULL);
    if (status != XST_SUCCESS) {
        xil_printf("IP completion interrupt connection failed\n");
        return -1;
    }
    XScuGic_Enable(&IntcInstance, XPAR_FABRIC_DCP_HAZEREMOVAL_0_O_INTR_INTR);

    // Exception handling setup
    Xil_ExceptionInit();
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
                                 (Xil_ExceptionHandler)XScuGic_InterruptHandler,
                                 (void *)&IntcInstance);
    Xil_ExceptionEnable();

    // Convert RGB image to 32-bit AXI format
    prepareImageStream();

    xil_printf("Starting image processing...\n");

    // Main processing loop
    while (1) {
        // Reset flags
        dmaRxDone = 0;
        ipProcessingDone = 0;

        // Start DMA receive transfer (IP -> memory)
        status = XAxiDma_SimpleTransfer(&myDma, (u32)processedStream,
                                        IMAGE_STREAM_SIZE, XAXIDMA_DEVICE_TO_DMA);
        if (status != XST_SUCCESS) {
            xil_printf("DMA receive setup failed\n");
            return -1;
        }

        // Start DMA send transfer (memory -> IP)
        status = XAxiDma_SimpleTransfer(&myDma, (u32)imageStream,
                                        IMAGE_STREAM_SIZE, XAXIDMA_DMA_TO_DEVICE);
        if (status != XST_SUCCESS) {
            xil_printf("DMA send setup failed\n");
            return -1;
        }

        // Wait for DMA receive completion
        while (!dmaRxDone);

        xil_printf("Image processed, sending RGB data to PC...\n");

        // Send 24-bit RGB data to PC via UART
        sendRgbDataToPC();

        xil_printf("RGB data transmission complete\n");

        // Wait for IP completion interrupt to trigger retransmission
        // This implements your requirement: "when interrupt signal is detected it transmits again"
        while (!ipProcessingDone);

        xil_printf("IP completion detected, preparing for retransmission...\n");
    }

    return 0;
}

// Convert RGB byte data to 32-bit AXI stream format: 0x00RRGGBB
void prepareImageStream(void) {
    for (int i = 0; i < NUM_PIXELS; i++) {
        u8 R = imageData[i * 3 + 0];
        u8 G = imageData[i * 3 + 1];
        u8 B = imageData[i * 3 + 2];
        // Pack RGB into 32-bit word with upper 8 bits as 0 (as per your IP design)
        imageStream[i] = (R << 16) | (G << 8) | B;
    }
}

// Send 24-bit RGB data to PC via UART (3 bytes per pixel)
void sendRgbDataToPC(void) {
    u32 totalPixelsSent = 0;
    const u32 pixelsPerChunk = 341; // ~1KB chunks (341 pixels × 3 bytes = 1023 bytes)

    while (totalPixelsSent < NUM_PIXELS) {
        u32 pixelsInThisChunk = (NUM_PIXELS - totalPixelsSent > pixelsPerChunk) ?
                                pixelsPerChunk : (NUM_PIXELS - totalPixelsSent);

        // Send RGB bytes for this chunk
        for (u32 i = 0; i < pixelsInThisChunk; i++) {
            u32 pixelIndex = totalPixelsSent + i;
            u32 pixel32bit = processedStream[pixelIndex];

            // Extract 24-bit RGB from 32-bit word (0x00RRGGBB)
            u8 rgbBytes[3];
            rgbBytes[0] = (pixel32bit >> 16) & 0xFF; // Red
            rgbBytes[1] = (pixel32bit >> 8) & 0xFF;  // Green
            rgbBytes[2] = pixel32bit & 0xFF;         // Blue

            // Send 3 bytes (24-bit RGB) for this pixel
            u32 bytesSent = 0;
            while (bytesSent < 3) {
                u32 sent = XUartPs_Send(&myUart, &rgbBytes[bytesSent], 3 - bytesSent);
                bytesSent += sent;
                // Wait for transmission to complete before sending more
                while (XUartPs_IsSending(&myUart));
            }
        }

        totalPixelsSent += pixelsInThisChunk;

        // Optional: Add small delay between chunks to prevent UART overflow
        usleep(100); // 100 microseconds
    }
}

// DMA S2MM Interrupt Handler (when processed data is received from IP)
static void dmaReceiveISR(void *CallBackRef) {
    XAxiDma_IntrDisable((XAxiDma *)CallBackRef, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);
    XAxiDma_IntrAckIrq((XAxiDma *)CallBackRef, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);
    dmaRxDone = 1;
    XAxiDma_IntrEnable((XAxiDma *)CallBackRef, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);
}

// Custom IP Completion Interrupt Handler (triggers retransmission)
static void ipCompletionISR(void *CallBackRef) {
    // Acknowledge the interrupt from your custom IP
    // NOTE: You may need to clear interrupt registers in your IP here
    // For example: Xil_Out32(YOUR_IP_BASE_ADDR + INTERRUPT_CLEAR_REG, 0x1);

    ipProcessingDone = 1;

    xil_printf("IP completion interrupt received\n");
}
