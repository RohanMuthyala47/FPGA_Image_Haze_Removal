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


def dehaze_image(hazy_img, patch_size=15, omega=0.9375, t0=0.1, r=60, eps=0.003):
    dark_channel = get_dark_channel(hazy_img, patch_size)
    A = estimate_atmospheric_light(hazy_img, dark_channel)

    raw_transmission = 1 - omega * dark_channel
    gray_img = cv2.cvtColor((hazy_img*255).astype(np.uint8), cv2.COLOR_RGB2GRAY) / 255.0
    refined_transmission = guided_filter(gray_img, raw_transmission, r, eps)

    refined_transmission = np.maximum(refined_transmission, t0)

    dehazed_img = (hazy_img - A) / refined_transmission[..., None] + A
    dehazed_img = np.clip(dehazed_img, 0, 1)

    return dehazed_img, refined_transmission


# Load the hazy image
# r"C:\Users\Rohan\Downloads\archive\RESIDE-6K\training\hazy\4.jpg"
# r"C:\Users\Rohan\Documents\Images\newyork.jpg"
hazy_img = cv2.imread(r"C:\Users\Rohan\Documents\Images\canyon.jpg")
hazy_img = cv2.cvtColor(hazy_img, cv2.COLOR_BGR2RGB)
hazy_img = hazy_img.astype(np.float32) / 255.0

# Dehaze
dehazed_img, transmission_map = dehaze_image(hazy_img)

# Display results
plt.figure(figsize=(40,18))

plt.subplot(1, 3, 1)
plt.imshow(hazy_img)
plt.title("Hazy Image")
plt.axis("off")

plt.subplot(1, 3, 2)
plt.imshow(dehazed_img)
plt.title("Dehazed Image")
plt.axis("off")

plt.subplot(1, 3, 3)
plt.imshow(transmission_map, cmap='gray')
plt.title("Transmission Map")
plt.axis("off")

plt.show()

# Convert back to 0–255 uint8
output_img = (dehazed_img * 255).astype(np.uint8)

# Save as JPG using OpenCV
# cv2.imwrite(r"C:\Users\Rohan\Documents\Images\dehazed_town.jpg", cv2.cvtColor(output_img, cv2.COLOR_RGB2BGR))


