import cv2
import numpy as np
import matplotlib.pyplot as plt


def get_dark_channel(img, patch_size):
    """Compute dark channel using minimum filter"""
    min_channel = np.min(img, axis=2)
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (patch_size, patch_size))
    dark_channel = cv2.erode(min_channel, kernel)
    return dark_channel


def estimate_atmospheric_light_paper(img, dark_channel):
    """
    Atmospheric light estimation using extremum approximate method
    as described in the paper
    """
    # Find the pixel with maximum value in dark channel
    max_pos = np.unravel_index(np.argmax(dark_channel), dark_channel.shape)

    # Get the corresponding pixel value from original image
    A = img[max_pos[0], max_pos[1], :].copy()

    # Apply adjustment parameter σ = 0.875 as mentioned in paper
    sigma = 0.875
    A = sigma * A

    return A


def edge_detection(img, threshold=80):
    """
    Edge detection as described in equation (9) of the paper
    Returns edge detection result: 0=no edge, 1=horizontal/vertical edge, 2=diagonal edge
    """
    h, w, c = img.shape
    ED = np.zeros((h, w), dtype=np.int32)

    # Convert to integer to avoid overflow issues
    img_int = (img * 255).astype(np.int32)

    for i in range(1, h - 1):
        for j in range(1, w - 1):
            # Check diagonal edges
            diagonal_edge = False
            for ch in range(c):
                if (abs(img_int[i - 1, j - 1, ch] - img_int[i + 1, j + 1, ch]) >= threshold or
                        abs(img_int[i - 1, j + 1, ch] - img_int[i + 1, j - 1, ch]) >= threshold):
                    diagonal_edge = True
                    break

            if diagonal_edge:
                ED[i, j] = 2
                continue

            # Check horizontal/vertical edges
            hv_edge = False
            for ch in range(c):
                if (abs(img_int[i - 1, j, ch] - img_int[i + 1, j, ch]) >= threshold or
                        abs(img_int[i, j - 1, ch] - img_int[i, j + 1, ch]) >= threshold):
                    hv_edge = True
                    break

            if hv_edge:
                ED[i, j] = 1

    return ED


def apply_filters(img, i, j, ed_value):
    """
    Apply different filters based on edge detection result
    P0: mean filter, P1: edge-preserving filter (h/v), P2: edge-preserving filter (diagonal)
    """
    h, w, c = img.shape
    result = np.zeros(c)

    # Ensure we don't go out of bounds
    if i < 1 or i >= h - 1 or j < 1 or j >= w - 1:
        return img[i, j, :]

    if ed_value == 0:  # No edge - use mean filter P0
        for ch in range(c):
            result[ch] = (img[i - 1, j - 1, ch] + img[i - 1, j, ch] + img[i - 1, j + 1, ch] +
                          img[i, j - 1, ch] + img[i, j, ch] + img[i, j + 1, ch] +
                          img[i + 1, j - 1, ch] + img[i + 1, j, ch] + img[i + 1, j + 1, ch]) / 9

    elif ed_value == 1:  # Horizontal/vertical edge - use P1
        for ch in range(c):
            result[ch] = (img[i - 1, j - 1, ch] + 2 * img[i - 1, j, ch] + img[i - 1, j + 1, ch] +
                          2 * img[i, j - 1, ch] + 4 * img[i, j, ch] + 2 * img[i, j + 1, ch] +
                          img[i + 1, j - 1, ch] + 2 * img[i + 1, j, ch] + img[i + 1, j + 1, ch]) / 16

    elif ed_value == 2:  # Diagonal edge - use P2
        for ch in range(c):
            result[ch] = (2 * img[i - 1, j - 1, ch] + img[i - 1, j, ch] + 2 * img[i - 1, j + 1, ch] +
                          img[i, j - 1, ch] + 4 * img[i, j, ch] + img[i, j + 1, ch] +
                          2 * img[i + 1, j - 1, ch] + img[i + 1, j, ch] + 2 * img[i + 1, j + 1, ch]) / 16

    return result


def estimate_transmission_paper(img, A, omega_prime=0.9375):
    """
    Transmission estimation using the paper's method with edge-preserving filters
    """
    h, w, c = img.shape

    # Edge detection
    ED = edge_detection(img)

    # Initialize transmission map
    transmission = np.zeros((h, w))

    for i in range(h):
        for j in range(w):
            # Apply appropriate filter based on edge detection
            filtered_pixel = apply_filters(img, i, j, ED[i, j])

            # Compute transmission using equation (10)
            min_val = np.inf
            for ch in range(c):
                if A[ch] > 0:  # Avoid division by zero
                    min_val = min(min_val, filtered_pixel[ch] / A[ch])

            transmission[i, j] = 1 - omega_prime * min_val

    return transmission, ED


def guided_filter(I, p, r, eps):
    """Guided filter implementation"""
    mean_I = cv2.boxFilter(I, ddepth=-1, ksize=(r, r))
    mean_p = cv2.boxFilter(p, ddepth=-1, ksize=(r, r))
    corr_I = cv2.boxFilter(I * I, ddepth=-1, ksize=(r, r))
    corr_Ip = cv2.boxFilter(I * p, ddepth=-1, ksize=(r, r))

    var_I = corr_I - mean_I * mean_I
    cov_Ip = corr_Ip - mean_I * mean_p

    a = cov_Ip / (var_I + eps)
    b = mean_p - a * mean_I

    mean_a = cv2.boxFilter(a, ddepth=-1, ksize=(r, r))
    mean_b = cv2.boxFilter(b, ddepth=-1, ksize=(r, r))

    return mean_a * I + mean_b


def saturation_correction(img, A, beta=0.3):
    """
    Saturation correction as described in equation (12)
    """
    corrected = np.zeros_like(img)
    for ch in range(3):
        if A[ch] > 0:
            corrected[:, :, ch] = (A[ch] ** beta) * (img[:, :, ch] ** (1 - beta))
        else:
            corrected[:, :, ch] = img[:, :, ch]

    return corrected


def dehaze_image_paper(hazy_img, patch_size=7, omega_prime=0.9375, t0=0.25,
                       r=7, eps=0.003, use_guided_filter=True):
    """
    Complete haze removal using the paper's method
    """
    # Step 1: Compute dark channel using 3x3 minimum filter (as per paper)
    dark_channel = get_dark_channel(hazy_img, patch_size)

    # Step 2: Atmospheric light estimation using extremum approximate method
    A = estimate_atmospheric_light_paper(hazy_img, dark_channel)

    # Step 3: Transmission estimation using edge-preserving filters
    raw_transmission, edge_map = estimate_transmission_paper(hazy_img, A, omega_prime)

    # Step 4: Optionally apply guided filter to refine transmission
    if use_guided_filter:
        gray_img = cv2.cvtColor((hazy_img * 255).astype(np.uint8), cv2.COLOR_RGB2GRAY) / 255.0
        refined_transmission = guided_filter(gray_img, raw_transmission, r, eps)
    else:
        refined_transmission = raw_transmission

    # Apply lower bound
    refined_transmission = np.maximum(refined_transmission, t0)

    # Step 5: Scene recovery
    dehazed_img = np.zeros_like(hazy_img)
    for ch in range(3):
        dehazed_img[:, :, ch] = (hazy_img[:, :, ch] - A[ch]) / refined_transmission + A[ch]

    # Clip values to valid range
    dehazed_img = np.clip(dehazed_img, 0, 1)

    # Step 6: Saturation correction
    final_img = saturation_correction(dehazed_img, A)
    final_img = np.clip(final_img, 0, 1)

    return final_img, refined_transmission, raw_transmission, edge_map, A


# Load the hazy image
hazy_img = cv2.imread(r"C:\Users\Rohan\Documents\Images\canyon_512.bmp")
hazy_img = cv2.cvtColor(hazy_img, cv2.COLOR_BGR2RGB)
hazy_img = hazy_img.astype(np.float32) / 255.0

# Apply paper's method
print("Processing with paper's method...")
dehazed_img, final_transmission, raw_transmission, edge_map, atmospheric_light = dehaze_image_paper(
    hazy_img, use_guided_filter=True)

print(f"Atmospheric light: {atmospheric_light}")

# Display results
plt.figure(figsize=(20, 10))

plt.subplot(2, 3, 1)
plt.imshow(hazy_img)
plt.title("Original Hazy Image")
plt.axis("off")

plt.subplot(2, 3, 2)
plt.imshow(dehazed_img)
plt.title("Dehazed Image (Paper's Method)")
plt.axis("off")

plt.subplot(2, 3, 3)
plt.imshow(edge_map, cmap='viridis')
plt.title("Edge Detection Map")
plt.colorbar()
plt.axis("off")

plt.subplot(2, 3, 4)
plt.imshow(raw_transmission, cmap='gray')
plt.title("Raw Transmission (Paper's Method)")
plt.axis("off")

plt.subplot(2, 3, 5)
plt.imshow(final_transmission, cmap='gray')
plt.title("Refined Transmission (After Guided Filter)")
plt.axis("off")

plt.subplot(2, 3, 6)
# Show difference between raw and refined transmission
diff = np.abs(final_transmission - raw_transmission)
plt.imshow(diff, cmap='hot')
plt.title("Transmission Difference (Refined - Raw)")
plt.colorbar()
plt.axis("off")

plt.tight_layout()
plt.show()

# Convert back to 0–255 uint8 for saving
output_img = (dehazed_img * 255).astype(np.uint8)

# Uncomment to save
# cv2.imwrite(r"C:\Users\Rohan\Documents\Images\dehazed_paper_method.jpg",
#            cv2.cvtColor(output_img, cv2.COLOR_RGB2BGR))