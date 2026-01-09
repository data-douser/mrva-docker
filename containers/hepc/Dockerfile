# Use a Python 3.11 image as the base
FROM python:3.11-slim

# Create application root
RUN mkdir -p /work-gh/mrva

# Copy source tree
WORKDIR /work-gh/mrva
COPY ./mrvahepc mrvahepc

# Switch to hepc source directory
WORKDIR /work-gh/mrva/mrvahepc

# We're in a container: install globally
RUN pip install --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install .

# Canonical values mount (authoritative, read-only at runtime)
VOLUME /mrva/values

# Expose service port
EXPOSE 8070

# Run global service (no path arguments)
CMD ["hepc-serve-global", \
     "--host", "0.0.0.0", \
     "--port", "8070" \
]
