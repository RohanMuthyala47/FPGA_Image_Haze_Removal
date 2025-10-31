/**
 * @file Image_HazeRemoval_SW_Only_Optimized.c
 * @brief Software-only driver for Image Haze Removal System (Optimized)
 * @description Complete software implementation of Shiau et al. (2013) haze removal
 *              with improved memory management, error handling, and performance.
 *
 * @author Rohan M
 * @date 31st October 2025
 * @version 3.0
 *
 * Key Improvements:
 * - Proper malloc error checking throughout
 * - Efficient buffer reuse strategy
 * - Compile with -O3 -mfpu=neon-vfpv4 -mfloat-abi=hard for best performance
 * - Added progress indicators
 * - Robust UART transmission with backoff
 */

//==========================================================================================
// SYSTEM INCLUDES
//==========================================================================================
#include "xparameters.h"
#include "xuartps.h"
#include <xtime_l.h>
#include "sleep.h"
#include "xil_cache.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "TestImage.h"

//==========================================================================================
// CONFIGURATION CONSTANTS
//==========================================================================================
#define BAUD_RATE        115200
#define BURST_SIZE       128

#define IMG_WIDTH        512
#define IMG_HEIGHT       512
#define IMG_SIZE         (IMG_WIDTH * IMG_HEIGHT)
#define NUMBER_OF_BYTES  (IMG_SIZE * 3)

// Algorithm parameters (Shiau et al. 2013)
#define SIGMA            0.875f      // Atmospheric light scaling
#define D_THRESHOLD      80          // Edge detection threshold
#define OMEGA_PRIME      0.9375f     // Transmission estimation weight
#define T0               0.25f       // Minimum transmission
#define BETA             0.3f        // Saturation correction exponent

//==========================================================================================
// TYPE DEFINITIONS
//==========================================================================================
typedef struct {
    float r, g, b;
} Pixel_f;

//==========================================================================================
// GLOBAL BUFFERS
//==========================================================================================
static u8 FinalData[NUMBER_OF_BYTES];   // Final output buffer
static Pixel_f Ac;                       // Atmospheric light

//==========================================================================================
// INLINE UTILITY FUNCTIONS
//==========================================================================================
static inline float clampf(float v, float min, float max) {
    return (v < min) ? min : ((v > max) ? max : v);
}

static inline float min3f(float a, float b, float c) {
    float m = a;
    if (b < m) m = b;
    if (c < m) m = c;
    return m;
}

static inline float max3f(float a, float b, float c) {
    float m = a;
    if (b > m) m = b;
    if (c > m) m = c;
    return m;
}

/**
 * @brief Reflective boundary pixel access
 * Mirrors pixel coordinates at image boundaries
 */
static inline float get_pixel_reflect(const float *channel, int row, int col) {
    if (row < 0) row = -row;
    if (row >= IMG_HEIGHT) row = 2 * IMG_HEIGHT - row - 2;
    if (col < 0) col = -col;
    if (col >= IMG_WIDTH) col = 2 * IMG_WIDTH - col - 2;
    return channel[row * IMG_WIDTH + col];
}

//==========================================================================================
// IMAGE PROCESSING FUNCTIONS
//==========================================================================================

/**
 * @brief Convert packed 32-bit RGB to planar float format
 * Input format: [31:24]=unused [23:16]=R [15:8]=G [7:0]=B
 * Output format: Planar [R R R ... G G G ... B B B ...]
 */
void convert_to_float_planar(const u32 *input, float *output) {
    float *r_plane = output;
    float *g_plane = output + IMG_SIZE;
    float *b_plane = output + IMG_SIZE * 2;
    
    for (int i = 0; i < IMG_SIZE; i++) {
        u32 pixel = input[i];
        r_plane[i] = (float)((pixel >> 16) & 0xFF);
        g_plane[i] = (float)((pixel >> 8) & 0xFF);
        b_plane[i] = (float)(pixel & 0xFF);
    }
}

/**
 * @brief Apply 3x3 minimum filter (morphological erosion)
 * Used for dark channel prior computation
 */
void min_filter_3x3(const float *input, float *output) {
    for (int row = 0; row < IMG_HEIGHT; row++) {
        for (int col = 0; col < IMG_WIDTH; col++) {
            float min_val = 255.0f;
            
            // 3x3 neighborhood with reflection
            for (int dr = -1; dr <= 1; dr++) {
                for (int dc = -1; dc <= 1; dc++) {
                    float val = get_pixel_reflect(input, row + dr, col + dc);
                    if (val < min_val) min_val = val;
                }
            }
            
            output[row * IMG_WIDTH + col] = min_val;
        }
    }
}

/**
 * @brief Estimate atmospheric light using dark channel prior
 * Finds the pixel with maximum dark channel value and scales by sigma
 */
void compute_atmospheric_light(const float *img_r, const float *img_g, const float *img_b,
                               Pixel_f *ac, int *loc_s, int *loc_t,
                               float *scratch_minR, float *scratch_minG, float *scratch_minB) {
    // Apply 3x3 min filter per channel
    min_filter_3x3(img_r, scratch_minR);
    min_filter_3x3(img_g, scratch_minG);
    min_filter_3x3(img_b, scratch_minB);
    
    // Find maximum of dark channel
    float max_val = -1.0f;
    int max_idx = 0;
    
    for (int i = 0; i < IMG_SIZE; i++) {
        float dark_prime = min3f(scratch_minR[i], scratch_minG[i], scratch_minB[i]);
        if (dark_prime > max_val) {
            max_val = dark_prime;
            max_idx = i;
        }
    }
    
    // Extract location
    *loc_s = max_idx / IMG_WIDTH;
    *loc_t = max_idx % IMG_WIDTH;
    
    // Atmospheric light with sigma scaling and minimum guard
    ac->r = clampf(img_r[max_idx] * SIGMA, 1e-3f, 255.0f);
    ac->g = clampf(img_g[max_idx] * SIGMA, 1e-3f, 255.0f);
    ac->b = clampf(img_b[max_idx] * SIGMA, 1e-3f, 255.0f);
}

/**
 * @brief Compute Edge Detection (ED) map
 * Classifies pixels as: 0=smooth, 1=V/H edge, 2=diagonal edge
 */
void compute_ED_map(const float *img_r, const float *img_g, const float *img_b, u8 *ed) {
    int offsets[8][2] = {{-1,-1}, {-1,0}, {-1,1}, {0,-1}, {0,1}, {1,-1}, {1,0}, {1,1}};
    
    for (int row = 0; row < IMG_HEIGHT; row++) {
        for (int col = 0; col < IMG_WIDTH; col++) {
            int i = row * IMG_WIDTH + col;
            
            // Sample 8-connected neighbors
            float r_n[8], g_n[8], b_n[8];
            for (int n = 0; n < 8; n++) {
                int nr = row + offsets[n][0];
                int nc = col + offsets[n][1];
                r_n[n] = get_pixel_reflect(img_r, nr, nc);
                g_n[n] = get_pixel_reflect(img_g, nr, nc);
                b_n[n] = get_pixel_reflect(img_b, nr, nc);
            }
            
            // Compute differences: diagonal and vertical/horizontal
            float diff_d1 = max3f(fabsf(r_n[0] - r_n[7]), fabsf(g_n[0] - g_n[7]), fabsf(b_n[0] - b_n[7]));
            float diff_d2 = max3f(fabsf(r_n[2] - r_n[5]), fabsf(g_n[2] - g_n[5]), fabsf(b_n[2] - b_n[5]));
            float diff_v  = max3f(fabsf(r_n[1] - r_n[6]), fabsf(g_n[1] - g_n[6]), fabsf(b_n[1] - g_n[6]));
            float diff_h  = max3f(fabsf(r_n[3] - r_n[4]), fabsf(g_n[3] - g_n[4]), fabsf(b_n[3] - b_n[4]));
            
            // Classify edge type
            if (diff_d1 >= D_THRESHOLD || diff_d2 >= D_THRESHOLD)
                ed[i] = 2;  // Diagonal edge
            else if (diff_v >= D_THRESHOLD || diff_h >= D_THRESHOLD)
                ed[i] = 1;  // Vertical/horizontal edge
            else
                ed[i] = 0;  // Smooth region
        }
    }
}

/**
 * @brief Apply 2D convolution with reflection padding
 */
void apply_filter(const float *input, float *output, const float *kernel, int ksize) {
    int offset = ksize / 2;
    
    for (int row = 0; row < IMG_HEIGHT; row++) {
        for (int col = 0; col < IMG_WIDTH; col++) {
            float sum = 0.0f;
            
            for (int kr = 0; kr < ksize; kr++) {
                for (int kc = 0; kc < ksize; kc++) {
                    int img_row = row - offset + kr;
                    int img_col = col - offset + kc;
                    float val = get_pixel_reflect(input, img_row, img_col);
                    sum += val * kernel[kr * ksize + kc];
                }
            }
            
            output[row * IMG_WIDTH + col] = sum;
        }
    }
}

/**
 * @brief Estimate transmission map with ED-adaptive filtering
 * Uses three different kernels based on edge classification
 */
int estimate_transmission(const float *img_r, const float *img_g, const float *img_b,
                         const Pixel_f *ac, const u8 *ed, float *t_out,
                         float *tmp0_r, float *tmp0_g, float *tmp0_b,
                         float *tmp1_r, float *tmp1_g, float *tmp1_b,
                         float *tmp2_r, float *tmp2_g, float *tmp2_b) {
    // Define filter kernels
    float k0[9] = {1,1,1, 1,1,1, 1,1,1};  // Uniform filter
    for (int i = 0; i < 9; i++) k0[i] /= 9.0f;
    
    float k1[9] = {1,2,1, 2,4,2, 1,2,1};  // Gaussian-like
    for (int i = 0; i < 9; i++) k1[i] /= 16.0f;
    
    float k2[9] = {2,1,2, 1,4,1, 2,1,2};  // Inverse Gaussian
    for (int i = 0; i < 9; i++) k2[i] /= 16.0f;
    
    // Apply all three filters to each channel
    apply_filter(img_r, tmp0_r, k0, 3);
    apply_filter(img_g, tmp0_g, k0, 3);
    apply_filter(img_b, tmp0_b, k0, 3);
    
    apply_filter(img_r, tmp1_r, k1, 3);
    apply_filter(img_g, tmp1_g, k1, 3);
    apply_filter(img_b, tmp1_b, k1, 3);
    
    apply_filter(img_r, tmp2_r, k2, 3);
    apply_filter(img_g, tmp2_g, k2, 3);
    apply_filter(img_b, tmp2_b, k2, 3);
    
    // Compute transmission map
    for (int i = 0; i < IMG_SIZE; i++) {
        float Pc_r, Pc_g, Pc_b;
        
        // Select filtered value based on ED classification
        switch (ed[i]) {
            case 0:  // Smooth region
                Pc_r = tmp0_r[i];
                Pc_g = tmp0_g[i];
                Pc_b = tmp0_b[i];
                break;
            case 1:  // V/H edge
                Pc_r = tmp1_r[i];
                Pc_g = tmp1_g[i];
                Pc_b = tmp1_b[i];
                break;
            case 2:  // Diagonal edge
                Pc_r = tmp2_r[i];
                Pc_g = tmp2_g[i];
                Pc_b = tmp2_b[i];
                break;
            default:
                Pc_r = tmp0_r[i];
                Pc_g = tmp0_g[i];
                Pc_b = tmp0_b[i];
        }
        
        // Compute min_c(Pc[c] / Ac[c])
        float ratio_r = Pc_r / ac->r;
        float ratio_g = Pc_g / ac->g;
        float ratio_b = Pc_b / ac->b;
        float min_ratio = min3f(ratio_r, ratio_g, ratio_b);
        
        // t = 1 - omega' * min_ratio
        t_out[i] = clampf(1.0f - OMEGA_PRIME * min_ratio, 0.0f, 1.0f);
    }
    
    return 0;
}

/**
 * @brief Recover scene radiance using transmission map
 * J_c = (I_c - A_c) / max(t, t0) + A_c
 */
void recover_scene(const float *img_r, const float *img_g, const float *img_b,
                   const Pixel_f *ac, const float *t,
                   float *out_r, float *out_g, float *out_b) {
    for (int i = 0; i < IMG_SIZE; i++) {
        float t_clamped = (t[i] > T0) ? t[i] : T0;
        
        out_r[i] = (img_r[i] - ac->r) / t_clamped + ac->r;
        out_g[i] = (img_g[i] - ac->g) / t_clamped + ac->g;
        out_b[i] = (img_b[i] - ac->b) / t_clamped + ac->b;
    }
}

/**
 * @brief Apply saturation correction and pack to 8-bit RGB
 * J_tilde_c = (A_c)^beta * J_c^(1-beta)
 */
void saturation_correction_and_pack(const float *j_r, const float *j_g, const float *j_b,
                                    const Pixel_f *ac, u8 *out_interleaved) {
    // Precompute atmospheric light powers
    float ac_norm_r = clampf(ac->r / 255.0f, 1e-6f, 1.0f);
    float ac_norm_g = clampf(ac->g / 255.0f, 1e-6f, 1.0f);
    float ac_norm_b = clampf(ac->b / 255.0f, 1e-6f, 1.0f);
    
    float ac_beta_r = powf(ac_norm_r, BETA);
    float ac_beta_g = powf(ac_norm_g, BETA);
    float ac_beta_b = powf(ac_norm_b, BETA);
    float one_minus_beta = 1.0f - BETA;
    
    for (int i = 0; i < IMG_SIZE; i++) {
        // Normalize to [0, 1]
        float jr = clampf(j_r[i] / 255.0f, 0.0f, 1.0f);
        float jg = clampf(j_g[i] / 255.0f, 0.0f, 1.0f);
        float jb = clampf(j_b[i] / 255.0f, 0.0f, 1.0f);
        
        // Apply saturation correction
        float cr = ac_beta_r * powf(jr, one_minus_beta);
        float cg = ac_beta_g * powf(jg, one_minus_beta);
        float cb = ac_beta_b * powf(jb, one_minus_beta);
        
        // Convert to 8-bit with rounding
        int ir = (int)(clampf(cr * 255.0f, 0.0f, 255.0f) + 0.5f);
        int ig = (int)(clampf(cg * 255.0f, 0.0f, 255.0f) + 0.5f);
        int ib = (int)(clampf(cb * 255.0f, 0.0f, 255.0f) + 0.5f);
        
        out_interleaved[i * 3 + 0] = (u8)ir;
        out_interleaved[i * 3 + 1] = (u8)ig;
        out_interleaved[i * 3 + 2] = (u8)ib;
    }
}

//==========================================================================================
// MAIN FUNCTION
//==========================================================================================
int main(void) {
    XUartPs_Config *UART_Config;
    XUartPs UART_Instance;
    u32 status;
    XTime t_start, t_end;
    int loc_s = 0, loc_t = 0;
    
    // Allocate large working buffers
    float *img_float = (float*)malloc(sizeof(float) * IMG_SIZE * 3);
    float *t_map = (float*)malloc(sizeof(float) * IMG_SIZE);
    u8 *ED_map = (u8*)malloc(sizeof(u8) * IMG_SIZE);
    
    if (!img_float || !t_map || !ED_map) {
        xil_printf("ERROR: Failed to allocate main working buffers\n");
        if (img_float) free(img_float);
        if (t_map) free(t_map);
        if (ED_map) free(ED_map);
        return -1;
    }
    
    // Allocate scratch buffers for intermediate results
    float *s_minR = (float*)malloc(sizeof(float) * IMG_SIZE);
    float *s_minG = (float*)malloc(sizeof(float) * IMG_SIZE);
    float *s_minB = (float*)malloc(sizeof(float) * IMG_SIZE);
    
    float *tmp0_r = (float*)malloc(sizeof(float) * IMG_SIZE);
    float *tmp0_g = (float*)malloc(sizeof(float) * IMG_SIZE);
    float *tmp0_b = (float*)malloc(sizeof(float) * IMG_SIZE);
    float *tmp1_r = (float*)malloc(sizeof(float) * IMG_SIZE);
    float *tmp1_g = (float*)malloc(sizeof(float) * IMG_SIZE);
    float *tmp1_b = (float*)malloc(sizeof(float) * IMG_SIZE);
    float *tmp2_r = (float*)malloc(sizeof(float) * IMG_SIZE);
    float *tmp2_g = (float*)malloc(sizeof(float) * IMG_SIZE);
    float *tmp2_b = (float*)malloc(sizeof(float) * IMG_SIZE);
    
    float *j_r = (float*)malloc(sizeof(float) * IMG_SIZE);
    float *j_g = (float*)malloc(sizeof(float) * IMG_SIZE);
    float *j_b = (float*)malloc(sizeof(float) * IMG_SIZE);
    
    if (!s_minR || !s_minG || !s_minB ||
        !tmp0_r || !tmp0_g || !tmp0_b ||
        !tmp1_r || !tmp1_g || !tmp1_b ||
        !tmp2_r || !tmp2_g || !tmp2_b ||
        !j_r || !j_g || !j_b) {
        xil_printf("ERROR: Failed to allocate scratch buffers\n");
        goto cleanup_and_exit;
    }
    
    //==================================================================================
    // UART INITIALIZATION
    //==================================================================================
    UART_Config = XUartPs_LookupConfig(XPAR_PS7_UART_1_DEVICE_ID);
    status = XUartPs_CfgInitialize(&UART_Instance, UART_Config, UART_Config->BaseAddress);
    if (status != XST_SUCCESS) {
        xil_printf("ERROR: UART initialization failed\n");
        goto cleanup_and_exit;
    }
    
    status = XUartPs_SetBaudRate(&UART_Instance, BAUD_RATE);
    if (status != XST_SUCCESS) {
        xil_printf("ERROR: UART baud rate configuration failed\n");
        goto cleanup_and_exit;
    }
    
    xil_printf("\n=== Software Haze Removal Started ===\n");
    xil_printf("Image size: %dx%d pixels\n", IMG_WIDTH, IMG_HEIGHT);
    
    //==================================================================================
    // IMAGE PROCESSING PIPELINE
    //==================================================================================
    Xil_DCacheFlush();
    XTime_GetTime(&t_start);
    
    // Step 1: Convert to planar float format
    xil_printf("[1/6] Converting image format...\n");
    float *img_r = img_float;
    float *img_g = img_float + IMG_SIZE;
    float *img_b = img_float + IMG_SIZE * 2;
    convert_to_float_planar(imageData, img_float);
    
    // Step 2: Atmospheric light estimation
    xil_printf("[2/6] Computing atmospheric light...\n");
    compute_atmospheric_light(img_r, img_g, img_b, &Ac, &loc_s, &loc_t, s_minR, s_minG, s_minB);
    xil_printf("      Ac = (R:%.2f, G:%.2f, B:%.2f) at pixel (%d,%d)\n",
               Ac.r, Ac.g, Ac.b, loc_s, loc_t);
    
    // Step 3: Edge detection map
    xil_printf("[3/6] Computing edge detection map...\n");
    compute_ED_map(img_r, img_g, img_b, ED_map);
    
    // Step 4: Transmission estimation
    xil_printf("[4/6] Estimating transmission map...\n");
    estimate_transmission(img_r, img_g, img_b, &Ac, ED_map, t_map,
                         tmp0_r, tmp0_g, tmp0_b,
                         tmp1_r, tmp1_g, tmp1_b,
                         tmp2_r, tmp2_g, tmp2_b);
    
    // Step 5: Scene recovery
    xil_printf("[5/6] Recovering scene radiance...\n");
    recover_scene(img_r, img_g, img_b, &Ac, t_map, j_r, j_g, j_b);
    
    // Step 6: Saturation correction
    xil_printf("[6/6] Applying saturation correction...\n");
    saturation_correction_and_pack(j_r, j_g, j_b, &Ac, FinalData);
    
    Xil_DCacheFlush();
    XTime_GetTime(&t_end);
    
    //==================================================================================
    // UART TRANSMISSION
    //==================================================================================
    xil_printf("Transmitting %d bytes via UART...\n", NUMBER_OF_BYTES);
    u32 total_sent = 0;
    u32 retry_count = 0;
    
    while (total_sent < NUMBER_OF_BYTES) {
        u32 sent = XUartPs_Send(&UART_Instance,
                                (u8*)&FinalData[total_sent],
                                BURST_SIZE);
        
        if (sent == 0) {
            // UART FIFO full - back off
            usleep(1000);  // 1ms delay
            retry_count++;
            if (retry_count > 1000) {
                xil_printf("ERROR: UART transmission timeout\n");
                goto cleanup_and_exit;
            }
            continue;
        }
        
        total_sent += sent;
        retry_count = 0;
        
        // Wait for transmission to complete
        while (XUartPs_IsSending(&UART_Instance)) {
            usleep(100);  // 100us
        }
        
        // Progress indicator every 25%
        if ((total_sent % (NUMBER_OF_BYTES / 4)) == 0) {
            xil_printf("  %d%% transmitted\n", (total_sent * 100) / NUMBER_OF_BYTES);
        }
    }
    
    //==================================================================================
    // PERFORMANCE REPORTING
    //==================================================================================
    double elapsed_ms = ((double)(t_end - t_start) * 1000.0) / (double)COUNTS_PER_SECOND;
    xil_printf("\n=== Processing Complete ===\n");
    xil_printf("Execution Time: %.2f ms\n", elapsed_ms);
    xil_printf("Throughput: %.2f Mpixels/sec\n", (IMG_SIZE / 1000000.0) / (elapsed_ms / 1000.0));
    xil_printf("============================\n\r");
    
cleanup_and_exit:
    // Free all allocated memory
    if (s_minR) free(s_minR);
    if (s_minG) free(s_minG);
    if (s_minB) free(s_minB);
    
    if (tmp0_r) free(tmp0_r);
    if (tmp0_g) free(tmp0_g);
    if (tmp0_b) free(tmp0_b);
    if (tmp1_r) free(tmp1_r);
    if (tmp1_g) free(tmp1_g);
    if (tmp1_b) free(tmp1_b);
    if (tmp2_r) free(tmp2_r);
    if (tmp2_g) free(tmp2_g);
    if (tmp2_b) free(tmp2_b);
    
    if (j_r) free(j_r);
    if (j_g) free(j_g);
    if (j_b) free(j_b);
    
    if (img_float) free(img_float);
    if (t_map) free(t_map);
    if (ED_map) free(ED_map);
    
    return 0;
}
