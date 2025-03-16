from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_socketio import SocketIO
import base64
import cv2
import numpy as np
import logging
from ImageProcessor import process_image

# Setup logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)  # Allow cross-origin requests

# Initialize Flask-SocketIO
socketio = SocketIO(app)

@app.route('/process_image', methods=['POST'])
def process_image_route():
    logger.info("Received request to process image.")

    # Get JSON data from request
    data = request.get_json()
    
    if not data or 'image' not in data or 'image_edges' not in data:
        logger.error("Missing request parameters.")
        return jsonify({"error": "No image provided"}), 400
    
    image_edges = data.get('image_edges', None)  # Default to None if not provided
    logger.debug(f"Received image_edges: {image_edges}")

    # Decode the base64 image
    try:
        logger.info("Decoding base64 image data.")
        image_data = base64.b64decode(data['image'])
        np_arr = np.frombuffer(image_data, np.uint8)
        image = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)

        if image is None or image.size == 0:
            raise ValueError("Decoded image is empty or invalid.")

    except Exception as e:
        logger.error(f"Invalid image data: {e}")
        return jsonify({"error": f"Invalid image data: {e}"}), 400

    # Process the image
    try:
        logger.info("Processing image...")
        processed_image = process_image(image, image_edges)

        # Ensure processing didn't return None
        if processed_image is None or processed_image.size == 0:
            raise ValueError("Image processing failed, output is empty.")

        # Encode the processed image back to base64 for response
        _, buffer = cv2.imencode('.jpg', processed_image)
        processed_image_base64 = base64.b64encode(buffer).decode('utf-8')

        logger.info("Image processing successful.")
        return jsonify({'processed_image': processed_image_base64})

    except Exception as e:
        logger.error(f"Error during image processing: {e}")
        return jsonify({"error": f"Error processing image: {e}"}), 500

# SocketIO event handler
@socketio.on('connect')
def handle_connect():
    logger.info('Client connected via SocketIO')

@socketio.on('disconnect')
def handle_disconnect():
    logger.info('Client disconnected from SocketIO')

if __name__ == '__main__':
    logger.info("Starting Flask server on port 5000.")
    socketio.run(app, debug=True, host='0.0.0.0', port=5000)  # Start the app with SocketIO
