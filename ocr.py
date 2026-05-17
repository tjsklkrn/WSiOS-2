import sys
import Quartz
import Vision
from Cocoa import NSURL

def recognize_text(image_path):
    input_url = NSURL.fileURLWithPath_(image_path)
    handler = Vision.VNImageRequestHandler.alloc().initWithURL_options_(input_url, None)
    
    request = Vision.VNRecognizeTextRequest.alloc().init()
    request.setRecognitionLevel_(Vision.VNRequestTextRecognitionLevelAccurate)
    
    success, error = handler.performRequests_error_([request], None)
    if not success:
        print("Error:", error)
        return
        
    for observation in request.results():
        text = observation.topCandidates_(1)[0].string()
        bbox = observation.boundingBox()
        print(f"Text: '{text}' at x:{bbox.origin.x:.2f}, y:{bbox.origin.y:.2f}")

recognize_text(sys.argv[1])
