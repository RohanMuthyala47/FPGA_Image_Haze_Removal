#include "xaxidma.h"
#include "xparameters.h"
#include "sleep.h"
#include "xil_cache.h"
#include "xil_io.h"
#include "xscugic.h"
#include "ImageData_RGB.h"
#include "xuartps.h"

#define NO_PIXELS 512*512*3

#define IMG_WIDTH        512
#define IMG_HEIGHT       512
#define IMG_SIZE       (IMG_WIDTH * IMG_HEIGHT)
#define NO_OF_PASSES 2


XScuGic IntcInstance;
static void dmaReceiveISR(void *CallBackRef);
int done = 0;

int main(){


    u32 status;
	u32 totalTransmittedBytes=0;
	u32 transmittedBytes = 0;
	XUartPs_Config *myUartConfig;
	XUartPs myUart;

	//Initialize uart
	myUartConfig = XUartPs_LookupConfig(XPAR_PS7_UART_1_DEVICE_ID);
	status = XUartPs_CfgInitialize(&myUart, myUartConfig, myUartConfig->BaseAddress);
//	if(status != XST_SUCCESS)
//		print("Uart initialization failed...\n\r");
	status = XUartPs_SetBaudRate(&myUart, 230400);
//	if(status != XST_SUCCESS)
//		print("Baudrate init failed....\n\r");

	XAxiDma_Config *myDmaConfig;
	XAxiDma myDma;
    //DMA Controller Configuration
	myDmaConfig = XAxiDma_LookupConfigBaseAddr(XPAR_AXI_DMA_0_BASEADDR);
	status = XAxiDma_CfgInitialize(&myDma, myDmaConfig);
	if(status != XST_SUCCESS){
		print("DMA initialization failed\n");
		return -1;
	}

	XAxiDma_IntrEnable(&myDma, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);

	//Interrupt Controller Configuration
	XScuGic_Config *IntcConfig;
	IntcConfig = XScuGic_LookupConfig(XPAR_PS7_SCUGIC_0_DEVICE_ID);
	status =  XScuGic_CfgInitialize(&IntcInstance, IntcConfig, IntcConfig->CpuBaseAddress);

	if(status != XST_SUCCESS){
		xil_printf("Interrupt controller initialization failed..");
		return -1;
	}

	XScuGic_SetPriorityTriggerType(&IntcInstance,XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR,0xA1,3);
	status = XScuGic_Connect(&IntcInstance,XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR,(Xil_InterruptHandler)dmaReceiveISR,(void *)&myDma);
	if(status != XST_SUCCESS){
		xil_printf("Interrupt connection failed");
		return -1;
	}
	XScuGic_Enable(&IntcInstance,XPAR_FABRIC_AXI_DMA_0_S2MM_INTROUT_INTR);

	Xil_ExceptionInit();
	Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,(Xil_ExceptionHandler)XScuGic_InterruptHandler,(void *)&IntcInstance);
	Xil_ExceptionEnable();


	status = XAxiDma_SimpleTransfer(&myDma,(u32)imageData, IMG_SIZE * sizeof(u32), XAXIDMA_DEVICE_TO_DMA);

	status = XAxiDma_SimpleTransfer(&myDma,(u32)imageData, IMG_SIZE * sizeof(u32), XAXIDMA_DMA_TO_DEVICE);

//	status = XAxiDma_SimpleTransfer(&myDma, (u32)imageData, (IMG_SIZE * 2) * sizeof(u32), XAXIDMA_DMA_TO_DEVICE);

	if(status != XST_SUCCESS){
		print("DMA initialization failed\n");
		return -1;
	}

    while(!done){}

    u8 modifiedData[NO_PIXELS];

	int i;
	for (i = 0; i < NO_PIXELS; i = i+3) {
		modifiedData[i] = (u8)(imageData[i/3] >> 16);
		modifiedData[i+1] = (u8)(imageData[i/3] >> 8);
		modifiedData[i+2] = (u8)(imageData[i/3]);
	}

	while(totalTransmittedBytes < NO_PIXELS){
		transmittedBytes =  XUartPs_Send(&myUart,(u8*)&modifiedData[totalTransmittedBytes],1);
		totalTransmittedBytes += transmittedBytes;
		usleep(1000);
	}

}

static void dmaReceiveISR(void *CallBackRef){
	XAxiDma_IntrDisable((XAxiDma *)CallBackRef, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);
	XAxiDma_IntrAckIrq((XAxiDma *)CallBackRef, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);
	done = 1;
	XAxiDma_IntrEnable((XAxiDma *)CallBackRef, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);
}
