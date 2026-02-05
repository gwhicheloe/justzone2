#!/usr/bin/env python3
"""
Composite app screenshots into iPhone bezel mockup.
"""

from PIL import Image, ImageDraw
import os

# Paths
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BEZEL_PATH = os.path.join(SCRIPT_DIR, "iPhone 16 - Black - Portrait.png")

# Screenshots to process
SCREENSHOTS = [
    "PreWorkout.PNG",
    "Workout.PNG",
    "Activity.PNG",
    "Bubble.PNG",
    "Splash.PNG",
]

# Screen bounds for iPhone 16 bezel (1359x2736)
# Determined by analyzing bezel transparency:
# - Phone frame is opaque from ~x=32-90 and x=1268-1326
# - Screen transparent area: x=90-1268, y=90-2645
# - Dynamic Island at center top (y=123-234) is handled by bezel overlay
SCREEN_LEFT = 90
SCREEN_TOP = 90
SCREEN_RIGHT = 1268
SCREEN_BOTTOM = 2645

# Corner radius for iPhone 16 display (matched to bezel's rounded corners)
CORNER_RADIUS = 110


def add_rounded_corners(img, radius):
    """Apply rounded corners to an image by making corners transparent."""
    # Create a mask with rounded rectangle
    mask = Image.new("L", img.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([(0, 0), img.size], radius=radius, fill=255)

    # Apply mask to image alpha channel
    result = img.copy()
    result.putalpha(mask)
    return result


def create_mockup(bezel_path, screenshot_path, output_path):
    """Composite a screenshot into the phone bezel."""
    # Open images
    bezel = Image.open(bezel_path).convert("RGBA")
    screenshot = Image.open(screenshot_path).convert("RGBA")

    # Use hardcoded screen bounds
    left, top, right, bottom = SCREEN_LEFT, SCREEN_TOP, SCREEN_RIGHT, SCREEN_BOTTOM
    screen_width = right - left
    screen_height = bottom - top

    print(f"  Screen area: ({left}, {top}) to ({right}, {bottom})")
    print(f"  Screen size: {screen_width} x {screen_height}")

    # Resize screenshot to fit screen area
    screenshot_resized = screenshot.resize((screen_width, screen_height), Image.Resampling.LANCZOS)

    # Apply rounded corners to match phone's display corners
    screenshot_resized = add_rounded_corners(screenshot_resized, CORNER_RADIUS)

    # Create composite: start with screenshot, then overlay bezel
    # This way the bezel frame covers the screenshot edges
    result = Image.new("RGBA", bezel.size, (0, 0, 0, 0))

    # Paste screenshot at screen position
    result.paste(screenshot_resized, (left, top))

    # Overlay bezel on top (bezel has transparency for screen area)
    result = Image.alpha_composite(result, bezel)

    # Save result
    result.save(output_path, "PNG")
    print(f"  Saved: {output_path}")

def main():
    print("Creating iPhone mockups...")
    print(f"Bezel: {BEZEL_PATH}")

    # Check bezel exists
    if not os.path.exists(BEZEL_PATH):
        print(f"Error: Bezel not found at {BEZEL_PATH}")
        return

    # Process each screenshot
    for screenshot_name in SCREENSHOTS:
        screenshot_path = os.path.join(SCRIPT_DIR, screenshot_name)
        if not os.path.exists(screenshot_path):
            print(f"Skipping {screenshot_name} - not found")
            continue

        # Output name: screenshot name with -mockup suffix
        base_name = os.path.splitext(screenshot_name)[0]
        output_name = f"{base_name}-mockup.png"
        output_path = os.path.join(SCRIPT_DIR, output_name)

        print(f"\nProcessing: {screenshot_name}")
        create_mockup(BEZEL_PATH, screenshot_path, output_path)

    print("\nDone!")

if __name__ == "__main__":
    main()
