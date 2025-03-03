import cv2
import numpy as np

def pointOrder(pts):
# Orders points as [top-left, top-right, bottom-right, bottom-left]
    rect = np.zeros((4, 2), dtype="float32")

    # Sum of (x + y) gives an idea of top-left (min) and bottom-right (max)
    s = pts.sum(axis=1)
    rect[0] = pts[np.argmin(s)]  # Top-left
    rect[2] = pts[np.argmax(s)]  # Bottom-right

    # Difference of (x - y) helps to find top-right (min) and bottom-left (max)
    diff = np.diff(pts, axis=1)
    rect[1] = pts[np.argmin(diff)]  # Top-right
    rect[3] = pts[np.argmax(diff)]  # Bottom-left

    return rect
    
# Detects tarot card edges and returns 4 ordered points
def detectEdges(path):
    # Read image & convert to grayscale
    image = cv2.imread(path)
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    # Preprocessing: Blur and Edge Detection
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    edges = cv2.Canny(blurred, 50, 150)

    # Find contours
    contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    arc = max(contours, key=cv2.contourArea)

    # Douglas-Peucker approximate to a quadrilateral
    epsilon = 0.02 * cv2.arcLength(arc, True)
    approx = cv2.approxPolyDP(arc, epsilon, True)

    if len(approx) == 4:
        return image, pointOrder(approx.reshape(4, 2))  # Return ordered points
    else:
        #TODO convert to throw
        return image, None

# Debug: Draws a neon green quadrilateral around detected tarot card
def drawQuad(image, points):
    if points is not None:
        cv2.polylines(image, [np.int32(points)], isClosed=True, color=(57, 255, 20), thickness=3)
        cv2.imshow("Detected Card", image)
        cv2.waitKey(0)
        cv2.destroyAllWindows()
    else:
        print("Failed to detect a quadrilateral.")

# Warps the tarot card to a standard rectangle
def homography(image, points):
    if points is None:
        #TODO convert to throw
        print("Homography failed: No card detected.")
        return

    # Standard card size
    # TODO make dependent height
    width, height = 600, 900
    dst_pts = np.array([[0, 0], [width-1, 0], [width-1, height-1], [0, height-1]], dtype=np.float32)

    # Compute & apply homography matrix
    H = cv2.getPerspectiveTransform(points, dst_pts)
    newImage = cv2.warpPerspective(image, H, (width, height))

    return newImage

# Debug code
path = "tarot.jpg"
image, quadrilateral = detectEdges(path)
img = homography(image, quadrilateral)
drawQuad(image, quadrilateral)
cv2.imshow("Card", img)
cv2.waitKey(0)
cv2.destroyAllWindows()
