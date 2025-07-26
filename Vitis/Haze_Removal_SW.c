#include "xaxidma.h"
#include "xparameters.h"
#include "xparameters_ps.h"
#include "sleep.h"
#include "xil_cache.h"
#include "xil_io.h"
#include "xscugic.h"
#include "ImageData.h"
#include "xuartps.h"

#define ImageSize (512 * 512 * 3)

XScuGic IntcInstance;
static void imageProcISR(void *CallBackRef);
static void dmaReceiveISR(void *CallBackRef);
int done;

int main()
{
    u32 status;
	u32 totalTransmittedBytes=0;
	u32 transmittedBytes = 0;
	XUartPs_Config *myUartConfig;
	XUartPs myUart;

    myUartConfig = XUartPs_LookupConfig(0);

    status = XUartPs_CfgInitialize(&myUart, myUartConfig, myUartConfig->BaseAddress);
	if(status != XST_SUCCESS)
		print("Uart initialization failed...\n\r");
	status = XUartPs_SetBaudRate(&myUart, 115200);
	if(status != XST_SUCCESS)
		print("Baudrate init failed....\n\r");

	XAxiDma_Config *myDmaConfig;
	XAxiDma myDma;
    //DMA Controller Configuration
	myDmaConfig = XAxiDma_LookupConfig(0);
	status = XAxiDma_CfgInitialize(&myDma, myDmaConfig);
	if(status != XST_SUCCESS){
		print("DMA initialization failed\n");
		return -1;
	}

    XAxiDma_IntrEnable(&myDma, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);

    //Interrupt Controller Configuration
	XScuGic_Config *IntcConfig;
	IntcConfig = XScuGic_LookupConfig(XPAR_XSCUGIC_0_BASEADDR);
	status =  XScuGic_CfgInitialize(&IntcInstance, IntcConfig, IntcConfig->CpuBaseAddress);

	if(status != XST_SUCCESS){
		xil_printf("Interrupt controller initialization failed..");
		return -1;
	}

    XScuGic_SetPriorityTriggerType(&IntcInstance,61U,0xA0,3);
	status = XScuGic_Connect(&IntcInstance,61U,(Xil_InterruptHandler)imageProcISR,(void *)&myDma);
	if(status != XST_SUCCESS){
		xil_printf("Interrupt connection failed");
		return -1;
	}
	XScuGic_Enable(&IntcInstance,61U);

	XScuGic_SetPriorityTriggerType(&IntcInstance,62U,0xA1,3);
	status = XScuGic_Connect(&IntcInstance,62U,(Xil_InterruptHandler)dmaReceiveISR,(void *)&myDma);
	if(status != XST_SUCCESS){
		xil_printf("Interrupt connection failed");
		return -1;
	}
	XScuGic_Enable(&IntcInstance,62U);

	Xil_ExceptionInit();
	Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,(Xil_ExceptionHandler)XScuGic_InterruptHandler,(void *)&IntcInstance);
	Xil_ExceptionEnable();


	status = XAxiDma_SimpleTransfer(&myDma,(u32)image_data, 512*512*3,XAXIDMA_DEVICE_TO_DMA);
	status = XAxiDma_SimpleTransfer(&myDma,(u32)image_data, 4*512,XAXIDMA_DMA_TO_DEVICE);//typecasting in C/C++
	if(status != XST_SUCCESS){
		print("DMA initialization failed\n");
		return -1;
	}


    while(!done){

    }


	while(totalTransmittedBytes < ImageSize){
		transmittedBytes =  XUartPs_Send(&myUart,(u8*)&image_data[totalTransmittedBytes],1);
		totalTransmittedBytes += transmittedBytes;
		usleep(1000);
	}

}

u32 checkIdle(u32 baseAddress,u32 offset){
	u32 status;
	status = (XAxiDma_ReadReg(baseAddress,offset))&XAXIDMA_IDLE_MASK;
	return status;
}


static void imageProcISR(void *CallBackRef){
	static int i=4;
	int status;
	XScuGic_Disable(&IntcInstance,61U);
	status = checkIdle(XPAR_AXI_DMA_0_BASEADDR,0x4);
	while(status == 0)
		status = checkIdle(XPAR_AXI_DMA_0_BASEADDR,0x4);
	if(i<514){
		status = XAxiDma_SimpleTransfer((XAxiDma *)CallBackRef,(u32)&image_data[i*512],512,XAXIDMA_DMA_TO_DEVICE);
		i++;
	}
	XScuGic_Enable(&IntcInstance,61U);
}


static void dmaReceiveISR(void *CallBackRef){
	XAxiDma_IntrDisable((XAxiDma *)CallBackRef, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);
	XAxiDma_IntrAckIrq((XAxiDma *)CallBackRef, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);
	done = 1;
	XAxiDma_IntrEnable((XAxiDma *)CallBackRef, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);
}
