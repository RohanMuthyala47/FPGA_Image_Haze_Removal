import cv2
import numpy as np
import os

def get_dark_channel(image, win_size=3):
    """Compute the dark channel using a min filter."""
    min_channel = np.min(image, axis=2)
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (win_size, win_size))
    dark = cv2.erode(min_channel, kernel)
    return dark

def estimate_atmospheric_light(image, dark, top_percent=0.001):
    """Estimate atmospheric light A using brightest pixels in dark channel."""
    h, w = dark.shape
    num_pixels = h * w
    num_top = max(1, int(num_pixels * top_percent))

    dark_vec = dark.reshape(-1)
    image_vec = image.reshape(-1, 3)

    indices = np.argsort(dark_vec)[-num_top:]
    brightest = image_vec[indices]
    A = brightest[np.argmax(np.sum(brightest, axis=1))]
    return A

def estimate_transmission(image, A, d=3, sigma_color=20, sigma_space=20, t0=0.1):
    """Transmission estimation using bilateral filter per channel."""
    norm_I = np.empty_like(image, dtype=np.float32)
    for c in range(3):
        channel = image[:,:,c].astype(np.float32)
        bilateral = cv2.bilateralFilter(channel, d, sigma_color, sigma_space)
        norm_I[:,:,c] = bilateral / (A[c] + 1e-6)

    t = 1 - np.min(norm_I, axis=2)
    return np.clip(t, t0, 1)

def recover_image(image, t, A, t0=0.1):
    """Recover the haze-free image using the atmospheric scattering model."""
    t = np.maximum(t, t0)
    J = np.empty_like(image, dtype=np.float32)
    for c in range(3):
        J[:,:,c] = ((image[:,:,c] - A[c]) / t) + A[c]
    return np.clip(J, 0, 1)

def apply_saturation_correction_rgb(J, beta=0.3):
    """
    Hardware-friendly saturation correction directly in RGB.
    J: RGB image in [0,1]
    beta: saturation correction factor
    """
    J_mean = np.mean(J, axis=2, keepdims=True)
    J_sat = J + beta * (J - J_mean)
    J_sat = np.clip(J_sat, 0, 1)
    return J_sat

def dehaze_image(input_path, output_prefix="dehaze_out"):
    # Load image
    image_bgr = cv2.imread(input_path)
    if image_bgr is None:
        raise FileNotFoundError(f"Image not found: {input_path}")
    image = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB) / 255.0

    # Dark channel
    dark = get_dark_channel(image, win_size=3)

    # Atmospheric light
    A = estimate_atmospheric_light(image, dark, top_percent=0.001)

    # Transmission
    t = estimate_transmission(image, A, d=3)

    # Recovery
    J = recover_image(image, t, A)

    # Hardware-friendly saturation correction
    J_sat = apply_saturation_correction_rgb(J, beta=0.3)

    # Save outputs
    os.makedirs("outputs", exist_ok=True)
    cv2.imwrite(f"outputs/{output_prefix}_hazy.png", (image*255).astype(np.uint8)[..., ::-1])
    cv2.imwrite(f"outputs/{output_prefix}_dark.png", (dark*255).astype(np.uint8))
    cv2.imwrite(f"outputs/{output_prefix}_transmission.png", (t*255).astype(np.uint8))
    cv2.imwrite(f"outputs/{output_prefix}_recovered.png", (J*255).astype(np.uint8)[..., ::-1])
    cv2.imwrite(f"outputs/{output_prefix}_saturation_corrected.png", (J_sat*255).astype(np.uint8)[..., ::-1])

    print("Dehazing and saturation correction complete. Results saved in 'outputs/' folder.")
    return J, J_sat, t, A

if __name__ == "__main__":
    # Change this path to your hazy image file
    INPUT_PATH = r"C:\Users\Rohan\Documents\Images\canyon_512.bmp"
    dehaze_image(INPUT_PATH, output_prefix="result")
