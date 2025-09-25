import cv2
import numpy as np
import time
import matplotlib.pyplot as plt

def min_filter_3x3(channel):
    """3x3 minimum filter using OpenCV erode (same as morphological minimum)."""
    kernel = np.ones((3,3), dtype=np.uint8)
    return cv2.erode(channel, kernel, borderType=cv2.BORDER_REFLECT)

def compute_atmospheric_light(img, sigma=1):
    """
    img: HxWx3 uint8 or float image in range [0,255]
    Returns: atmospheric light Ac as float array [3]
    """
    # per-channel 3x3 minimum
    channels = cv2.split(img)
    minR = min_filter_3x3(channels[2])  # OpenCV BGR order: R=2,G=1,B=0
    minG = min_filter_3x3(channels[1])
    minB = min_filter_3x3(channels[0])

    # Idark'(i,j) = min(minR, minG, minB)
    idark_prime = np.minimum(np.minimum(minR, minG), minB)

    # Find maximum value Adark and its location (s,t)
    idx = np.unravel_index(np.argmax(idark_prime, axis=None), idark_prime.shape)
    s, t = idx

    # atmospheric light is pixel I(s,t) scaled by sigma
    Ac = img[s, t].astype(np.float32) * sigma
    Ac = np.clip(Ac, 1e-3, 255.0)
    return Ac, (s, t), idark_prime

def estimate_transmission_fixed(img, Ac, omega_prime=0.984375):
    """
    Transmission estimation using only P2 kernel for all pixels.
    img: float image HxWx3 (BGR)
    Ac: atmospheric light per channel [B,G,R] floats
    Returns t map float in [0,1]
    """
    # define P2 kernel
    k2 = np.array([[2,1,2],
                   [1,4,1],
                   [2,1,2]], dtype=np.float32) / 16.0

    H, W, _ = img.shape
    P2 = np.zeros_like(img, dtype=np.float32)

    # filter each channel
    for c in range(3):
        P2[:, :, c] = cv2.filter2D(img[:, :, c], -1, k2, borderType=cv2.BORDER_REFLECT)

    # compute min_c ( Pc[c] / Ac[c] )
    Ac_arr = np.array(Ac, dtype=np.float32).reshape((1,1,3))
    ratio = P2 / Ac_arr
    min_ratio = np.min(ratio, axis=2)

    t = 1.0 - omega_prime * min_ratio
    t = np.clip(t, 0.0, 1.0)
    return t

def recover_scene(img, Ac, t_map, t0=0.1):
    """
    Reconstruct scene J using Eq: Jc = (Ic - Ac) / max(t, t0) + Ac
    """
    Ac_arr = np.array(Ac, dtype=np.float32).reshape((1,1,3))
    t_clamped = np.maximum(t_map, t0)[:, :, np.newaxis]  # shape HxWx1
    J = (img.astype(np.float32) - Ac_arr) / t_clamped + Ac_arr
    return J

def saturation_correction(J, Ac, beta=0.3):
    """
    Eq: J_tilde_c = (Ac)^beta * J_c^(1-beta)
    Implemented using normalized values in [0,1] for exponentiation.
    """
    J_norm = np.clip(J / 255.0, 0.0, 1.0)
    Ac_norm = np.clip(np.array(Ac, dtype=np.float32) / 255.0, 1e-6, 1.0)

    J_out = np.zeros_like(J_norm)
    for c in range(3):
        J_out[:, :, c] = (Ac_norm[c] ** beta) * (J_norm[:, :, c] ** (1.0 - beta))

    J_out = np.clip(J_out * 255.0, 0, 255).astype(np.uint8)
    return J_out

def dehaze_shiau_fixed(img_bgr_uint8,
                       sigma=1,
                       omega_prime=0.9375,
                       t0=0.35,
                       beta=0.3):
    """
    Full pipeline using only P2 kernel for all pixels.
    Input: uint8 BGR image (HxWx3)
    Returns: uint8 dehazed image (HxWx3)
    """
    img = img_bgr_uint8.astype(np.float32)

    # 1) Atmospheric light estimation
    Ac, (s,t), idark_prime = compute_atmospheric_light(img, sigma=sigma)

    # 2) Transmission estimation using only P2
    t_map = estimate_transmission_fixed(img, Ac, omega_prime=omega_prime)

    # 3) Scene recovery
    J = recover_scene(img, Ac, t_map, t0=t0)

    # 4) Saturation correction
    J_final = saturation_correction(J, Ac, beta=beta)

    return J_final, {
        'Ac': Ac,
        'Ac_loc': (s,t),
        't_map': t_map,
        'idark_prime': idark_prime
    }

if __name__ == "__main__":
    src_path = r"C:\Users\Rohan\Documents\Images\newyork.jpg"

    img = cv2.imread(src_path)
    if img is None:
        raise FileNotFoundError(f"Cannot read '{src_path}'")

    start = time.perf_counter()
    dehazed, meta = dehaze_shiau_fixed(img)
    end = time.perf_counter()
    print(f"Execution time: {end - start:.6f} seconds")

    # Save and show results
    cv2.imwrite("dehazed_fixed_p2.jpg", dehazed)
    plt.imshow(cv2.cvtColor(dehazed, cv2.COLOR_BGR2RGB))
    plt.title("Dehazed Image (P2 only)")
    plt.axis("off")
    plt.show()
