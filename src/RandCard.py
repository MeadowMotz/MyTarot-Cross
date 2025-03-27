import random
import cv2

def drawCard(choices): # Get a list of paths
    choice = random.choice(choices)
    result = cv2.imread(choice) # Choose one

    if (random.random()>0.5): # Randomly flip
        result = cv2.rotate(result, cv2.ROTATE_180)

    return result, choice