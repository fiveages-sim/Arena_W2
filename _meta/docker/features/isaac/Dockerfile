# Declared before every FROM so a later stage can use it as its base image.
# Default remains Isaac Sim 5.1.0. A newer release is a build argument:
#   --build-arg ISAAC_SIM_IMAGE=nvcr.io/nvidia/isaac-sim:6.1.0
#   --build-arg ISAAC_PYTHON=3.12
# ISAAC_PYTHON must match `python.sh` inside that Isaac image.
# 5.1.0 is 3.11. 6.1.0 is 3.12.
ARG ISAAC_SIM_IMAGE=nvcr.io/nvidia/isaac-sim:5.1.0
ARG ISAAC_PYTHON=3.11

# --- Stage 1: Builder (ROS Jazzy, Python matched to Isaac) ---
FROM osrf/ros:jazzy-desktop AS builder
ARG ISAAC_PYTHON

# Jazzy's own Python is 3.12. Isaac Sim 5.1.0 needs the 3.11 deadsnakes build.
RUN apt-get update && apt-get install -y software-properties-common && \
    if [ "$ISAAC_PYTHON" = "3.11" ]; then \
      add-apt-repository ppa:deadsnakes/ppa -y && apt-get update && \
      apt-get install -y python${ISAAC_PYTHON} python${ISAAC_PYTHON}-dev python${ISAAC_PYTHON}-venv; \
    else \
      apt-get install -y python${ISAAC_PYTHON} python${ISAAC_PYTHON}-dev python${ISAAC_PYTHON}-venv; \
    fi && \
    apt-get install -y \
      build-essential cmake git curl \
      python3-colcon-common-extensions && \
    rm -rf /var/lib/apt/lists/*

# 2. Create Venv and SET PATH (Forced Activation)
RUN python${ISAAC_PYTHON} -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
ENV VIRTUAL_ENV="/opt/venv"

# 3. Fail the build if the venv is not the Python Isaac will load.
ENV ISAAC_PYTHON=${ISAAC_PYTHON}
RUN python --version && \
    python -c "import os, sys; want=tuple(int(p) for p in os.environ['ISAAC_PYTHON'].split('.')); assert sys.version_info[:2]==want, sys.version"

WORKDIR /opt/msg_build

ADD src/Arena/arena_isaac/isaacsim_msgs src/isaacsim_msgs
ADD src/deps/hunav/hunav_sim/hunav_msgs src/hunav_msgs
ADD src/Arena/utils/msgs/arena_people_msgs src/arena_people_msgs

# 4. Install build dependencies (Including NumPy for the C-extensions)
RUN . /opt/ros/jazzy/setup.sh && \
    pip install --upgrade pip && \
    pip install setuptools catkin_pkg empy==3.3.4 lark numpy

# 5. Build messages against the same Python minor version as Isaac.
RUN . /opt/ros/jazzy/setup.sh && \
    colcon build \
    --packages-select isaacsim_msgs hunav_msgs arena_people_msgs \
    --cmake-args \
    -DPYTHON_EXECUTABLE=/opt/venv/bin/python \
    -DPYTHON_LIBRARY=/usr/lib/x86_64-linux-gnu/libpython${ISAAC_PYTHON}.so.1.0 \
    -DPYTHON_INCLUDE_DIR=/usr/include/python${ISAAC_PYTHON} \
    -DROSIDL_GENERATOR_PY_PYTHON_EXECUTABLE=/opt/venv/bin/python

# --- Stage 2: Final Isaac Sim Image ---
FROM ${ISAAC_SIM_IMAGE}
ARG ISAAC_PYTHON

# 6. Switch to root to fix system libs and paths
USER root

# Install cattrs directly into Isaac's internal site-packages to ensure it persists
RUN /isaac-sim/python.sh -m pip install cattrs pyyaml

# Isaac 5.1.0 has no libpython3.11. Isaac 6.1.0 already ships libpython3.12,
# so keep the image copy when it is already there.
COPY --from=builder /usr/lib/x86_64-linux-gnu/libpython${ISAAC_PYTHON}.so.1.0 /tmp/libpython-from-builder.so
RUN if [ ! -e /usr/lib/x86_64-linux-gnu/libpython${ISAAC_PYTHON}.so.1.0 ]; then \
      mv /tmp/libpython-from-builder.so /usr/lib/x86_64-linux-gnu/libpython${ISAAC_PYTHON}.so.1.0; \
    else \
      rm /tmp/libpython-from-builder.so; \
    fi && ldconfig

# Copy the built messages
COPY --from=builder /opt/msg_build/install /opt/isaac_bridge_msgs

# 7. Persistent Environment Setup
# We write to /root/.bashrc because Isaac Sim's launch scripts often wipe 'ENV' variables
RUN echo 'export ROS_DISTRO=jazzy' >> /root/.bashrc && \
    echo 'export ACCEPT_EULA=Y' >> /root/.bashrc && \
    echo 'export PRIVACY_CONSENT=Y' >> /root/.bashrc && \
    echo 'export RMW_IMPLEMENTATION=rmw_fastrtps_cpp' >> /root/.bashrc && \
    echo 'export AMENT_PREFIX_PATH=/isaac-sim/exts/isaacsim.ros2.bridge/jazzy:/isaac-sim/exts/isaacsim.ros2.core/jazzy:$AMENT_PREFIX_PATH' >> /root/.bashrc && \
    echo 'export ROS_DOMAIN_ID=1' >> /root/.bashrc && \
    echo 'export PYTHONPATH=/isaac-sim/exts/isaacsim.ros2.bridge/jazzy/python:/isaac-sim/exts/isaacsim.ros2.core/jazzy/rclpy:$PYTHONPATH' >> /root/.bashrc && \
    echo 'export LD_LIBRARY_PATH=/isaac-sim/exts/isaacsim.ros2.bridge/jazzy/rclpy/:/isaac-sim/exts/isaacsim.ros2.bridge/jazzy/lib/:/isaac-sim/exts/isaacsim.ros2.core/jazzy/rclpy/:/isaac-sim/exts/isaacsim.ros2.core/jazzy/lib/:$LD_LIBRARY_PATH' >> /root/.bashrc

# Both layouts are listed. Isaac 5.1 uses ros2.bridge/jazzy/python.
# Isaac 6.1 moved the same Jazzy libraries to ros2.core/jazzy/rclpy.
# A missing directory on PYTHONPATH or LD_LIBRARY_PATH is ignored.
ENV ROS_DISTRO=jazzy \
    AMENT_PREFIX_PATH=/isaac-sim/exts/isaacsim.ros2.bridge/jazzy:/isaac-sim/exts/isaacsim.ros2.core/jazzy \
    PYTHONPATH=/isaac-sim/exts/isaacsim.ros2.bridge/jazzy/python:/isaac-sim/exts/isaacsim.ros2.core/jazzy/rclpy \
    LD_LIBRARY_PATH=/isaac-sim/exts/isaacsim.ros2.bridge/jazzy/rclpy/:/isaac-sim/exts/isaacsim.ros2.bridge/jazzy/lib/:/isaac-sim/exts/isaacsim.ros2.core/jazzy/rclpy/:/isaac-sim/exts/isaacsim.ros2.core/jazzy/lib/

RUN printf '#!/bin/bash\nexec /isaac-sim/python.sh "$@"\n' > /usr/local/bin/python3 && chmod +x /usr/local/bin/python3
RUN printf '#!/bin/bash\nsource /opt/isaac_bridge_msgs/local_setup.bash > /dev/null 2>&1\nexec python3 "$@"\n' > /usr/local/bin/python3-arena && chmod +x /usr/local/bin/python3-arena

ENTRYPOINT [ "bash" ]