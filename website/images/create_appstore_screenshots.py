#!/usr/bin/env python3
"""
Create App Store Connect compatible screenshots.
Resizes screenshots to required dimensions with proper padding/scaling.
"""

from PIL import Image
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# App Store required sizes (6.7" display - iPhone 14 Plus, 13/12 Pro Max)
APPSTORE_WIDTH = 1284
APPSTORE_HEIGHT = 2778

# Screenshots to process
SCREENSHOTS = [
    "PreWorkout.PNG",
    "Workout.PNG",
    "Activity.PNG",
    "Bubble.PNG",
]

def create_appstore_screenshot(screenshot_path, output_path):
    """Resize screenshot to App Store dimensions."""
    img = Image.open(screenshot_path).convert("RGB")

    # Calculate scaling to fit within App Store dimensions while maintaining aspect ratio
    orig_width, orig_height = img.size

    # Scale to fit width, then check height
    scale = APPSTORE_WIDTH / orig_width
    new_height = int(orig_height * scale)

    if new_height > APPSTORE_HEIGHT:
        # Scale to fit height instead
        scale = APPSTORE_HEIGHT / orig_height
        new_width = int(orig_width * scale)
        new_height = APPSTORE_HEIGHT
    else:
        new_width = APPSTORE_WIDTH

    # Resize image
    img_resized = img.resize((new_width, new_height), Image.Resampling.LANCZOS)

    # Create canvas with black background at exact App Store size
    canvas = Image.new("RGB", (APPSTORE_WIDTH, APPSTORE_HEIGHT), (0, 0, 0))

    # Center the screenshot on canvas
    x = (APPSTORE_WIDTH - new_width) // 2
    y = (APPSTORE_HEIGHT - new_height) // 2
    canvas.paste(img_resized, (x, y))

    canvas.save(output_path, "PNG")
    print(f"  Saved: {output_path} ({APPSTORE_WIDTH}x{APPSTORE_HEIGHT})")

def main():
    print("Creating App Store screenshots...")
    print(f"Target size: {APPSTORE_WIDTH} x {APPSTORE_HEIGHT}")

    # Create output directory
    output_dir = os.path.join(SCRIPT_DIR, "appstore")
    os.makedirs(output_dir, exist_ok=True)

    for screenshot_name in SCREENSHOTS:
        screenshot_path = os.path.join(SCRIPT_DIR, screenshot_name)
        if not os.path.exists(screenshot_path):
            print(f"Skipping {screenshot_name} - not found")
            continue

        base_name = os.path.splitext(screenshot_name)[0]
        output_path = os.path.join(output_dir, f"{base_name}-appstore.png")

        print(f"\nProcessing: {screenshot_name}")
        create_appstore_screenshot(screenshot_path, output_path)

    print(f"\nDone! Screenshots saved to: {output_dir}")

if __name__ == "__main__":
    main()
