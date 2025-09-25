import cv2
import numpy as np
import matplotlib.pyplot as plt


def get_dark_channel(img, patch_size):
    min_channel = np.min(img, axis=2)
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (patch_size, patch_size))
    dark_channel = cv2.erode(min_channel, kernel)
    return dark_channel


def estimate_atmospheric_light(img, dark_channel):
    num_pixels = dark_channel.size
    top_pixels = int(0.001 * num_pixels)

    flat_dark = dark_channel.ravel()
    flat_img = img.reshape((-1, 3))

    indices = np.argsort(flat_dark)[-top_pixels:]
    A = np.max(flat_img[indices], axis=0)
    return A


def guided_filter(I, p, r, eps):
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


def compute_raw_transmission(hazy_img, dark_channel, omega=0.85, patch_size=7):
    raw_trans = 1 - omega * dark_channel

    # Edge detection
    gray = cv2.cvtColor((hazy_img * 255).astype(np.uint8), cv2.COLOR_RGB2GRAY)
    edges = cv2.Canny(gray, 50, 150)

    filtered_trans = np.zeros_like(raw_trans)
    pad = patch_size // 2
    padded_trans = cv2.copyMakeBorder(raw_trans, pad, pad, pad, pad, cv2.BORDER_REFLECT)

    for i in range(raw_trans.shape[0]):
        for j in range(raw_trans.shape[1]):
            patch = padded_trans[i:i + patch_size, j:j + patch_size]
            edge_patch = edges[i:i + patch_size, j:j + patch_size]

            if np.sum(edge_patch) > 0:
                # Stronger edge-preserving filter
                filtered_patch = cv2.bilateralFilter(
                    patch.astype(np.float32), d=9, sigmaColor=25, sigmaSpace=9
                )
                filtered_value = filtered_patch[patch_size // 2, patch_size // 2]

            else:
                # No edge → mean filter
                filtered_value = np.mean(patch)

            filtered_trans[i, j] = filtered_value

    return filtered_trans


def dehaze_image(hazy_img, patch_size=7, omega=0.9375, t0=0.1, r=7, eps=0.003, beta=0.25):
    dark_channel = get_dark_channel(hazy_img, patch_size)
    A = estimate_atmospheric_light(hazy_img, dark_channel)

    raw_transmission = compute_raw_transmission(hazy_img, dark_channel, omega, patch_size)

    gray_img = cv2.cvtColor((hazy_img * 255).astype(np.uint8), cv2.COLOR_RGB2GRAY) / 255.0
    refined_transmission = guided_filter(gray_img, raw_transmission, r, eps)

    refined_transmission = np.maximum(refined_transmission, t0)

    # Initial dehazed image
    J = (hazy_img - A) / refined_transmission[..., None] + A
    J = np.clip(J, 0, 1)

    # Saturation correction
    A_expanded = A.reshape((1, 1, 3))  # match image shape
    J_corrected = (A_expanded ** beta) * (J ** (1 - beta))
    J_corrected = np.clip(J_corrected, 0, 1)

    return J_corrected, refined_transmission, raw_transmission


# Load the hazy image
hazy_img = cv2.imread(r"C:\Users\Rohan\Documents\Images\newyork.jpg")
hazy_img = cv2.cvtColor(hazy_img, cv2.COLOR_BGR2RGB)
hazy_img = hazy_img.astype(np.float32) / 255.0

# Dehaze with saturation correction
dehazed_img, transmission_map, raw_transmission = dehaze_image(hazy_img, beta=0.25)

# Display results
plt.figure(figsize=(60, 18))

plt.subplot(2, 2, 1)
plt.imshow(hazy_img)
plt.title("Hazy Image")
plt.axis("off")

plt.subplot(2, 2, 2)
plt.imshow(raw_transmission, cmap='gray')
plt.title("Raw Transmission (edge-aware)")
plt.axis("off")

plt.subplot(2, 2, 3)
plt.imshow(transmission_map, cmap='gray')
plt.title("Refined Transmission")
plt.axis("off")

plt.subplot(2, 2, 4)
plt.imshow(dehazed_img)
plt.title("Dehazed Image (Saturation Corrected)")
plt.axis("off")

plt.show()

# Save output
#output_img = (dehazed_img * 255).astype(np.uint8)
# cv2.imwrite(r"C:\Users\Rohan\Documents\Images\dehazed_canyon_corrected.jpg", cv2.cvtColor(output_img, cv2.COLOR_RGB2BGR))
