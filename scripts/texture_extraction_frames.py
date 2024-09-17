"""
This scripts' purpose is to retrive and save the frames of the texture being created.
This is done by substracting the structural frames from the original frames.
"""

import cv2
import numpy as np
import os
from pathlib import Path

# We define the paths
main_dir: Path = Path(__file__).resolve().parent.parent
movies_dir: Path = main_dir / "Movies"
img_dir_path: Path = main_dir / "Images"
example_img = img_dir_path / "barbara.jpg"
mask_dir_path: Path = img_dir_path / "masks"
structure_dir: Path = movies_dir / "anisotropic_frames"
texture_dir: Path = movies_dir / "anisotropic_reminder_frames"

# We load the mask
mask: np.ndarray = cv2.imread(str(mask_dir_path / "barbara_mask.jpg"), cv2.IMREAD_GRAYSCALE)
mask_binary: np.ndarray = mask > 255.0/2.0

# We load the structural frames
frame_ammount: int = len(os.listdir(structure_dir))
structure_frames: np.ndarray = np.empty((frame_ammount, *mask.shape, 3), dtype=np.uint8)
for idx, frame in enumerate(os.listdir(structure_dir)):
    structure_frames[idx] = cv2.imread(str(structure_dir / frame), cv2.IMREAD_COLOR)

# We load the original frame
img: np.array = structure_frames[0]

# We create the texture frames
texture_frames: np.ndarray = img - structure_frames + 0.5 * 255.0

# We apply the mask: all the elements of the mask should be white
for idx, frame in enumerate(texture_frames):
    texture_frames[idx][mask_binary] = [255, 255, 255]

# We save the texture frames
os.makedirs(texture_dir, exist_ok=True)
num_frames = len(texture_frames)
num_digits = len(str(num_frames))
for idx, frame in enumerate(texture_frames):
    # Ensure frame is in uint8 format
    frame_uint8 = (
        (frame * 255).astype(np.uint8)
        if frame.max() <= 1
        else frame.astype(np.uint8)
    )
    # Format filename with leading zeros
    filename = f"frame_{idx+1:0{num_digits}}.png"
    # Save the image
    cv2.imwrite(os.path.join(texture_dir, filename), frame_uint8)

if len(os.listdir(texture_dir)) != frame_ammount:
    raise Exception("Error saving texture frames!")
else:
    print("Texture frames saved successfully!")
