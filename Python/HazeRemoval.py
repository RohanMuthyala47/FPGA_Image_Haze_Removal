import cv2
import numpy as np

def min_filter_3x3(channel):
    """3x3 minimum filter using OpenCV erode (same as morphological minimum)."""
    kernel = np.ones((3,3), dtype=np.uint8)
    return cv2.erode(channel, kernel, borderType=cv2.BORDER_REFLECT)

def compute_atmospheric_light(img, sigma=0.875):
    """
    img: HxWx3 uint8 or float image in range [0,255]
    Returns: atmospheric light Ac as float array [3]
    """
    # per-channel 3x3 minimum
    channels = cv2.split(img)
    minR = min_filter_3x3(channels[2])  # OpenCV uses BGR order; we'll use R=2,G=1,B=0
    minG = min_filter_3x3(channels[1])
    minB = min_filter_3x3(channels[0])

    # Idark'(i,j) = min(minR, minG, minB)
    idark_prime = np.minimum(np.minimum(minR, minG), minB)

    # Find maximum value Adark and its location (s,t)
    idx = np.unravel_index(np.argmax(idark_prime, axis=None), idark_prime.shape)
    s, t = idx

    # atmospheric light is pixel I(s,t) scaled by sigma
    Ac = img[s, t].astype(np.float32) * sigma
    # avoid 0 in Ac to prevent divisions; clamp small values
    Ac = np.clip(Ac, 1e-3, 255.0)
    return Ac, (s, t), idark_prime

def compute_ED(img, D=80):
    """
    Compute ED(i,j) per paper's eqn (9).
    img: HxWx3 float image (BGR)
    Returns ED map with values 0,1,2
    """
    # pad to compute neighbors cleanly
    img_p = np.pad(img, ((1,1),(1,1),(0,0)), mode='reflect')
    H, W, _ = img.shape
    ED = np.zeros((H, W), dtype=np.uint8)

    # For each neighbor offset use vectorized differences
    # diagonal differences:
    diff_d1 = np.abs(img_p[0:H, 0:W] - img_p[2:H+2, 2:W+2])  # (i-1,j-1) - (i+1,j+1)
    diff_d2 = np.abs(img_p[0:H, 2:W+2] - img_p[2:H+2, 0:W])  # (i-1,j+1) - (i+1,j-1)
    # vertical/horizontal differences:
    diff_v = np.abs(img_p[0:H, 1:W+1] - img_p[2:H+2, 1:W+1])  # (i-1,j) - (i+1,j)
    diff_h = np.abs(img_p[1:H+1, 0:W] - img_p[1:H+1, 2:W+2])  # (i,j-1) - (i,j+1)

    # Take max across channels (paper's tests are "for c in {R,G,B}"
    max_d1 = diff_d1.max(axis=2)
    max_d2 = diff_d2.max(axis=2)
    max_v = diff_v.max(axis=2)
    max_h = diff_h.max(axis=2)

    diag_mask = (max_d1 >= D) | (max_d2 >= D)
    vh_mask = (max_v >= D) | (max_h >= D)

    ED[diag_mask] = 2
    ED[~diag_mask & vh_mask] = 1
    # else remain 0
    return ED

def apply_filter_kernels(img, ED):
    """
    Compute Pc_0, Pc_1, Pc_2 per-channel using convolution kernels described.
    Returns arrays P0, P1, P2 of shape HxWx3 (float).
    """
    # define kernels
    k0 = np.ones((3,3), dtype=np.float32) / 9.0
    k1 = np.array([[1,2,1],[2,4,2],[1,2,1]], dtype=np.float32) / 16.0
    k2 = np.array([[2,1,2],[1,4,1],[2,1,2]], dtype=np.float32) / 16.0

    P0 = np.zeros_like(img, dtype=np.float32)
    P1 = np.zeros_like(img, dtype=np.float32)
    P2 = np.zeros_like(img, dtype=np.float32)

    # use filter2D per channel
    for c in range(3):
        P0[:, :, c] = cv2.filter2D(img[:, :, c], -1, k0, borderType=cv2.BORDER_REFLECT)
        P1[:, :, c] = cv2.filter2D(img[:, :, c], -1, k1, borderType=cv2.BORDER_REFLECT)
        P2[:, :, c] = cv2.filter2D(img[:, :, c], -1, k2, borderType=cv2.BORDER_REFLECT)

    return P0, P1, P2

def estimate_transmission(img, Ac, D=80, omega_prime=0.9375):
    """
    img: float image HxWx3 (BGR)
    Ac: atmospheric light per channel [B,G,R] floats
    Returns t map float in [0,1]
    """
    H, W, _ = img.shape
    ED = compute_ED(img, D=D)
    P0, P1, P2 = apply_filter_kernels(img, ED)

    # Choose Pc according to ED
    Pc = np.zeros_like(img, dtype=np.float32)
    mask0 = (ED == 0)
    mask1 = (ED == 1)
    mask2 = (ED == 2)
    # broadcast masks to 3 channels
    Pc[mask0] = P0[mask0]
    Pc[mask1] = P1[mask1]
    Pc[mask2] = P2[mask2]

    # compute min_c ( Pc[c] / Ac[c] )  (Ac indexed per channel)
    # ensure Ac shape (1,1,3)
    Ac_arr = np.array(Ac, dtype=np.float32).reshape((1,1,3))
    # avoid division by zero
    ratio = Pc / Ac_arr
    min_ratio = np.min(ratio, axis=2)

    t = 1.0 - omega_prime * min_ratio
    # clamp to [0,1]
    t = np.clip(t, 0.0, 1.0)
    return t, ED

def recover_scene(img, Ac, t_map, t0=0.25):
    """
    Reconstruct scene J using Eq (11): Jc = (Ic - Ac) / max(t, t0) + Ac
    """
    H, W, _ = img.shape
    Ac_arr = np.array(Ac, dtype=np.float32).reshape((1,1,3))
    t_clamped = np.maximum(t_map, t0)[:, :, np.newaxis]  # shape HxWx1
    J = (img.astype(np.float32) - Ac_arr) / t_clamped + Ac_arr
    return J

def saturation_correction(J, Ac, beta=0.3):
    """
    Eq (12): J_tilde_c = (Ac)^beta * J_c^(1-beta)
    Implemented using normalized values in [0,1] for exponentiation.
    """
    # normalize to 0..1
    J_norm = np.clip(J / 255.0, 0.0, 1.0)
    Ac_norm = np.clip(np.array(Ac, dtype=np.float32) / 255.0, 1e-6, 1.0)

    # apply per channel
    J_out = np.zeros_like(J_norm)
    for c in range(3):
        J_out[:, :, c] = (Ac_norm[c] ** beta) * (J_norm[:, :, c] ** (1.0 - beta))

    # scale back to 0..255
    J_out = np.clip(J_out * 255.0, 0, 255).astype(np.uint8)
    return J_out

def dehaze_shiau(img_bgr_uint8,
                 sigma=0.875,
                 D=80,
                 omega_prime=0.9375,
                 t0=0.25,
                 beta=0.3):
    """
    Full pipeline implementing Shiau et al. (2013) haze removal.
    Input: uint8 BGR image (HxWx3)
    Returns: uint8 dehazed image (HxWx3)
    """
    # convert to float for math (keep range 0..255)
    img = img_bgr_uint8.astype(np.float32)

    # 1) Atmospheric light estimation (3x3 min -> pick max of Idark')
    Ac, (s,t), idark_prime = compute_atmospheric_light(img, sigma=sigma)

    # 2) Transmission estimation with ED and Pc filters
    t_map, ED = estimate_transmission(img, Ac, D=D, omega_prime=omega_prime)

    # 3) Scene recovery
    J = recover_scene(img, Ac, t_map, t0=t0)

    # 4) Saturation correction
    J_final = saturation_correction(J, Ac, beta=beta)

    return J_final, {
        'Ac': Ac,
        'Ac_loc': (s,t),
        't_map': t_map,
        'ED': ED,
        'idark_prime': idark_prime
    }

if __name__ == "__main__":
    # Example usage:
    src_path = r"C:\Users\Rohan\Documents\Images\newyork.jpg"     # replace with your input image path
    dst_path = "dehazed_shiau.png"

    img = cv2.imread(src_path)
    if img is None:
        raise FileNotFoundError(f"Cannot read '{src_path}'")

    dehazed, meta = dehaze_shiau(img)
    cv2.imwrite(dst_path, dehazed)
    print("Saved:", dst_path)
    print("Atmospheric light (BGR):", meta['Ac'], "at loc", meta['Ac_loc'])
