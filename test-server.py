#!/usr/bin/env python3
"""
Simple HTTP server for testing TrackerA11y coordinate mapping
"""

import http.server
import socketserver
import os
import webbrowser
from pathlib import Path

PORT = 8080
DIRECTORY = Path(__file__).parent

class TestHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)
    
    def end_headers(self):
        # Add headers to prevent caching during testing
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

def main():
    handler = TestHTTPRequestHandler
    
    with socketserver.TCPServer(("", PORT), handler) as httpd:
        print(f"🌐 Starting test server at http://localhost:{PORT}")
        print(f"📁 Serving files from: {DIRECTORY}")
        print(f"🔗 Test page: http://localhost:{PORT}/test-page.html")
        print("📋 Press Ctrl+C to stop the server")
        print()
        
        # Try to open the test page automatically
        try:
            test_url = f"http://localhost:{PORT}/test-page.html"
            print(f"🚀 Opening test page in default browser: {test_url}")
            webbrowser.open(test_url)
        except Exception as e:
            print(f"⚠️  Could not auto-open browser: {e}")
            print(f"   Please manually open: http://localhost:{PORT}/test-page.html")
        
        print()
        httpd.serve_forever()

if __name__ == "__main__":
    main()