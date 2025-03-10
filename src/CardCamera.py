from flask import Flask, request, jsonify
from flask_cors import CORS  # Enable CORS for local requests
import base64
from io import BytesIO
import cv2
import numpy as np

app = Flask(__name__)
CORS(app)  # Allow cross-origin requests

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
    image = path
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
        raise ValueError("Failed to detect a quadrilateral. Invalid contour.")

# Debug: Draws a neon green quadrilateral around detected tarot card
def drawQuad(image, points):
    if points is not None:
        # Draw quadrilateral on the image
        cv2.polylines(image, [np.int32(points)], isClosed=True, color=(57, 255, 20), thickness=3)
        
        # Convert BGR image to RGB for correct color display in matplotlib
        image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        
        # Use matplotlib to display the image
        plt.imshow(image_rgb)
        plt.title("Detected Card")
        plt.axis('off')  # Hide axes
        plt.show()
    else:
        print("Failed to detect a quadrilateral.")

# Warps the tarot card to a standard rectangle based on the detected quadrilateral
def homography(image, points):
    if points is None:
        raise ValueError("Homography failed: No card detected.")

    # Calculate the width and height of the quadrilateral (bounding box)
    rect = cv2.minAreaRect(np.array(points, dtype="float32"))
    box = cv2.boxPoints(rect)  # Get the four points of the bounding box
    box = np.int32(box)  # Convert to integer points
    
    # Get width and height of the bounding box
    width = int(rect[1][0])
    height = int(rect[1][1])

    # Reorder points if needed (rectangular order)
    ordered_points = pointOrder(box)

    # Compute homography matrix and apply to get the rectified image
    dst_pts = np.array([[0, 0], [width-1, 0], [width-1, height-1], [0, height-1]], dtype=np.float32)
    H = cv2.getPerspectiveTransform(ordered_points, dst_pts)
    newImage = cv2.warpPerspective(image, H, (width, height))

    return newImage

def process_image(image_data):
    # Decode the base64 image
    image_bytes = base64.b64decode(image_data)
    nparr = np.frombuffer(image_bytes, np.uint8)
    image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    image, quadrilateral = detectEdges(image)
    img = homography(image, quadrilateral)

    # Encode back to base64 to send back to Flutter
    _, buffer = cv2.imencode('.jpg', img)
    jpg_as_base64 = base64.b64encode(buffer).decode('utf-8')

    return jpg_as_base64

@app.route('/process_image', methods=['POST'])
def process_image_route():
    # Get the image from the request
    data = request.json
    image_data = data.get('image')

    # Process the image and return the base64 encoded result
    processed_image_base64 = process_image(image_data)

    return jsonify({'processed_image': processed_image_base64})

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)  # Set the host to 0.0.0.0 to allow local requests

# # Debug code
# path = "../assets/tarot.jpg"  # Ensure the path is correct
# image, quadrilateral = detectEdges(path)
# img = homography(image, quadrilateral)

# # Display original image with quadrilateral
# drawQuad(image, quadrilateral)

# # Show the rectified image (final result)
# img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)  # Convert BGR to RGB for correct color display
# plt.imshow(img_rgb)
# plt.title("Card Rectified")
# plt.axis('off')  # Hide axes
# plt.show()
# cv2.waitKey(0)
# cv2.destroyAllWindows()
