import cv2
import numpy as np
import logging

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)


def pointOrder(pts):
    # Orders points as [top-left, top-right, bottom-right, bottom-left]
    rect = np.zeros((4, 2), dtype="float32")
    s = pts.sum(axis=1)
    rect[0] = pts[np.argmin(s)]  # Top-left
    rect[2] = pts[np.argmax(s)]  # Bottom-right
    diff = np.diff(pts, axis=1)
    rect[1] = pts[np.argmin(diff)]  # Top-right
    rect[3] = pts[np.argmax(diff)]  # Bottom-left
    return rect

def detectEdges(image, quadrilateral):
    if (image is None):
        raise ValueError("Image is null")
    if (quadrilateral is None): 
        # Convert to grayscale
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        blurred = cv2.GaussianBlur(gray, (5, 5), 0)
        edges = cv2.Canny(blurred, 50, 150)

        contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        arc = max(contours, key=cv2.contourArea)
        epsilon = 0.02 * cv2.arcLength(arc, True)
        approx = cv2.approxPolyDP(arc, epsilon, True)
    else:
        approx = quadrilateral

    if len(approx) == 4:
        return pointOrder(approx.reshape(4, 2))
    else:
        raise ValueError("Failed to detect a quadrilateral. Invalid contour.")

def homography(image, points):
    if points is None:
        raise ValueError("Homography failed: No card detected.")

    rect = cv2.minAreaRect(np.array(points, dtype="float32"))
    box = cv2.boxPoints(rect)  # Get the four points of the bounding box
    box = np.int32(box)  # Convert to integer points
    
    width = int(rect[1][0])
    height = int(rect[1][1])
    ordered_points = pointOrder(box)

    dst_pts = np.array([[0, 0], [width-1, 0], [width-1, height-1], [0, height-1]], dtype=np.float32)
    H = cv2.getPerspectiveTransform(ordered_points, dst_pts)
    newImage = cv2.warpPerspective(image, H, (width, height))

    return newImage

def process_image(image, image_edges):
    logger.info("Detecting edges")
    quadrilateral = detectEdges(image, image_edges)
    logger.info("Applying homography")
    img = homography(image, quadrilateral)
    
    return img
