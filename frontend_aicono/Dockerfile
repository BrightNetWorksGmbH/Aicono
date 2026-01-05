FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git -b stable /flutter
ENV PATH="/flutter/bin:${PATH}"

# Enable Flutter web
RUN flutter config --enable-web

# Set working directory
WORKDIR /app

# Copy pubspec files first for better caching
COPY pubspec.yaml pubspec.lock ./

# Get dependencies
RUN flutter pub get

# Copy source code
COPY . ./

# Build the app for web
RUN flutter build web --release

# Create a simple server script for SPA routing
RUN echo '#!/usr/bin/env python3\n\
import http.server\n\
import socketserver\n\
import os\n\
import urllib.parse\n\
\n\
class SPAHandler(http.server.SimpleHTTPRequestHandler):\n\
    def end_headers(self):\n\
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")\n\
        self.send_header("Pragma", "no-cache")\n\
        self.send_header("Expires", "0")\n\
        super().end_headers()\n\
    \n\
    def do_GET(self):\n\
        # Parse the path\n\
        parsed_path = urllib.parse.urlparse(self.path)\n\
        path = parsed_path.path\n\
        \n\
        # If it is a file that exists, serve it\n\
        if os.path.isfile("." + path):\n\
            super().do_GET()\n\
        else:\n\
            # Otherwise, serve index.html for SPA routing\n\
            self.path = "/index.html"\n\
            super().do_GET()\n\
\n\
if __name__ == "__main__":\n\
    PORT = 8080\n\
    os.chdir("/app/build/web")\n\
    with socketserver.TCPServer(("", PORT), SPAHandler) as httpd:\n\
        print(f"Server running at port {PORT}")\n\
        httpd.serve_forever()\n\
' > /app/server.py

RUN chmod +x /app/server.py

# Expose port
EXPOSE 8080

# Start the server
CMD ["python3", "/app/server.py"]

