import cv2
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.widgets import Slider
from scipy import ndimage


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


def detect_edge_type(window):
    sobel_x = np.array([[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]])
    sobel_y = np.array([[-1, -2, -1], [0, 0, 0], [1, 2, 1]])

    diag1 = np.array([[2, 1, 0], [1, 0, -1], [0, -1, -2]])  # main diagonal
    diag2 = np.array([[0, 1, 2], [-1, 0, 1], [-2, -1, 0]])  # anti-diagonal

    edge_x = np.abs(ndimage.convolve(window, sobel_x, mode='constant'))
    edge_y = np.abs(ndimage.convolve(window, sobel_y, mode='constant'))
    edge_d1 = np.abs(ndimage.convolve(window, diag1, mode='constant'))
    edge_d2 = np.abs(ndimage.convolve(window, diag2, mode='constant'))

    orthogonal_strength = np.mean(edge_x) + np.mean(edge_y)
    diagonal_strength = np.mean(edge_d1) + np.mean(edge_d2)

    edge_threshold = 0.02

    if diagonal_strength > orthogonal_strength and diagonal_strength > edge_threshold:
        return 'diagonal'
    elif orthogonal_strength > edge_threshold:
        return 'orthogonal'
    else:
        return 'none'


def apply_edge_preserving_filter(transmission, window_size=7):
    h, w = transmission.shape
    filtered_transmission = np.copy(transmission)
    half_window = window_size // 2
    padded_transmission = np.pad(transmission, half_window, mode='reflect')

    for i in range(h):
        for j in range(w):
            window = padded_transmission[i:i + window_size, j:j + window_size]
            edge_type = detect_edge_type(window)

            if edge_type == 'diagonal':
                center_val = window[half_window, half_window]
                weights = np.exp(-0.5 * ((window - center_val) / 0.1) ** 2)
                weights /= np.sum(weights)
                filtered_transmission[i, j] = np.sum(window * weights)

            elif edge_type == 'orthogonal':
                center_val = window[half_window, half_window]
                weights = np.exp(-0.5 * ((window - center_val) / 0.2) ** 2)
                weights /= np.sum(weights)
                filtered_transmission[i, j] = np.sum(window * weights)

            else:
                filtered_transmission[i, j] = np.mean(window)

    return filtered_transmission


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


def dehaze_image(hazy_img, patch_size=1, omega=0.85, t0=0.1, r=1, eps=0.003):
    dark_channel = get_dark_channel(hazy_img, patch_size)
    A = estimate_atmospheric_light(hazy_img, dark_channel)

    raw_transmission = 1 - omega * dark_channel / np.max(A)
    filtered_transmission = apply_edge_preserving_filter(raw_transmission)

    gray_img = cv2.cvtColor((hazy_img * 255).astype(np.uint8), cv2.COLOR_RGB2GRAY) / 255.0
    refined_transmission = guided_filter(gray_img, filtered_transmission, r, eps)
    refined_transmission = np.maximum(refined_transmission, t0)

    dehazed_img = np.zeros_like(hazy_img)
    for c in range(3):
        dehazed_img[:, :, c] = (hazy_img[:, :, c] - A[c]) / refined_transmission + A[c]

    dehazed_img = np.clip(dehazed_img, 0, 1)
    return dehazed_img, refined_transmission, filtered_transmission, A


def apply_saturation_correction(dehazed_img, A, beta=0.3):
    A_normalized = A / 255.0
    J_corrected = (A_normalized ** beta) * (dehazed_img ** (1 - beta))
    return np.clip(J_corrected, 0, 1)


# -----------------------------
# Main script with interactive slider
# -----------------------------

# Load hazy image
hazy_img = cv2.imread(r"C:\Users\Rohan\Downloads\archive\RESIDE-6K\training\hazy\2.jpg")
hazy_img = cv2.cvtColor(hazy_img, cv2.COLOR_BGR2RGB)
hazy_img = hazy_img.astype(np.float32) / 255.0

# Run dehazing
dehazed_img, refined_transmission, raw_transmission, A = dehaze_image(hazy_img)

# Initial saturation correction
beta_init = 0.3
corrected_img = apply_saturation_correction(dehazed_img, A, beta=beta_init)

# Plot with slider
fig, ax = plt.subplots(1, 4, figsize=(20, 5))
plt.subplots_adjust(bottom=0.25)

ax[0].imshow(hazy_img)
ax[0].set_title("Hazy Image")
ax[0].axis("off")

im1 = ax[1].imshow(corrected_img)
ax[1].set_title(f"Dehazed (β={beta_init:.2f})")
ax[1].axis("off")

ax[2].imshow(raw_transmission, cmap='gray')
ax[2].set_title("Raw Transmission (Edge Preserving)")
ax[2].axis("off")

ax[3].imshow(refined_transmission, cmap='gray')
ax[3].set_title("Refined Transmission (Guided Filter)")
ax[3].axis("off")

# Slider for beta
ax_beta = plt.axes([0.25, 0.1, 0.5, 0.03])
slider_beta = Slider(ax_beta, 'Beta', 0.0, 1.0, valinit=beta_init, valstep=0.05)


def update(val):
    beta_val = slider_beta.val
    corrected = apply_saturation_correction(dehazed_img, A, beta=beta_val)
    im1.set_data(corrected)
    ax[1].set_title(f"Dehazed (β={beta_val:.2f})")
    fig.canvas.draw_idle()


slider_beta.on_changed(update)
plt.show()
